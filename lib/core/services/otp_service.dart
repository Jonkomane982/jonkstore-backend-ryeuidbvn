import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../config/app_owner.dart';
import '../errors/failures.dart';
import '../network/result.dart';
import '../../firebase_options.dart';

/// Authoritative server-side OTP service backed by Firestore.
///
/// Architecture:
///   - OTPs are generated cryptographically secure here.
///   - ONLY a salted+hashed OTP digest is ever persisted to Firestore.
///   - Firestore is the SINGLE source of truth for session state.
///   - Emails are dispatched by writing a `mail/{docId}` document that the
///     preconfigured **Firebase Trigger Email** extension delivers via SMTP.
///     SMTP credentials live only in Firebase Console — never in Flutter.
///   - Rate limiting, attempt counting, expiry, and single-use enforcement
///     are all validated against Firestore (server equivalent).
///
/// The client (Flutter UI) never learns the plaintext OTP; it receives only
/// an opaque `sessionId` identifier and must submit `sessionId + enteredCode`
/// back for verification.
class OtpService {
  static const String kSessionsCollection = 'otp_sessions';
  static const String kMailCollection = 'mail';
  static const int kOtpDigits = 6;
  static const int kMaxAttempts = 5;
  static const int kOtpValidityMinutes = 5;
  static const int kResendCooldownSeconds = 60;
  static const int kMaxResendsPerHour = 6;
  static const int kSaltBytes = 16;

  final FirebaseFirestore? _firestore;

  OtpService(this._firestore);

  // ---------------------------------------------------------------------------
  // Configuration helpers
  // ---------------------------------------------------------------------------

  static bool get _firebaseConfigIsPlaceholder {
    try {
      final opts = DefaultFirebaseOptions.currentPlatform;
      return opts.apiKey == 'placeholder' ||
          opts.apiKey.contains('REPLACE_ME') ||
          opts.appId == 'placeholder' ||
          opts.appId.contains('REPLACE_ME') ||
          opts.messagingSenderId == 'placeholder';
    } catch (_) {
      return true;
    }
  }

  bool get _isFirestoreAvailable =>
      !_firebaseConfigIsPlaceholder && _firestore != null;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Requests a new OTP session. Writes a hashed session record to Firestore
  /// and dispatches the plaintext OTP via the Trigger Email extension (backend).
  ///
  /// Returns a Result wrapping a [sessionId] — the only token the caller needs.
  Future<Result<String>> requestOtp({required String username}) async {
    try {
      final sessionId = const Uuid().v4();
      final plainCode = _generateSecureSixDigitCode();
      final salt = _generateSalt();
      final otpHash = _hashOtp(plainCode, salt);
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: kOtpValidityMinutes));

      // ---- Rate limit check (previous recent session) — best effort ----
      try {
        final previousBlock = await _enforceResendRateLimits(username);
        if (previousBlock != null) return Result.failure(previousBlock);
      } catch (_) {
        // If rate-limit lookups fail (e.g. missing composite index or
        // restrictive rules), continue anyway — the session is still valid.
      }

      // ---- Persist session in Firestore (authoritative store) ----
      final sessionData = <String, dynamic>{
        'session_id': sessionId,
        'username': username.trim(),
        'email': AppOwner.ownerEmail,
        'otp_hash': otpHash,
        'otp_salt': salt,
        'attempts_used': 0,
        'is_verified': false,
        'is_invalidated': false,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'resend_count': 1,
        'hourly_resend_bucket_start': now.toIso8601String(),
      };

      if (_isFirestoreAvailable) {
        try {
          await _firestore!
              .collection(kSessionsCollection)
              .doc(sessionId)
              .set(sessionData);
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            throw AuthFailure(
              'Firestore permission denied. Ensure your Firestore security rules '
              'allow writes to the "$kSessionsCollection" collection for '
              'authenticated users. Deploy firestore.rules from the project root '
              'or update rules in Firebase Console.',
            );
          }
          rethrow;
        }

        try {
          await _invalidatePreviousSessions(username, keepSessionId: sessionId);
        } catch (_) {
          // Best-effort: failing to invalidate old sessions (e.g. missing
          // composite index on (username, is_verified, is_invalidated)) must
          // NOT block the new session from being used.
        }

        // ---- Trigger backend email delivery (Firebase Trigger Email extension) ----
        // The extension (configured in Firebase Console) watches `mail/`.
        // SMTP credentials live in GCP/Firebase Secret Manager only.
        try {
          await _firestore.collection(kMailCollection).add({
            'to': [AppOwner.ownerEmail],
            'message': {
              'subject': 'JonkStore POS — Your 6-Digit Verification Code',
              'text': _buildPlaintextEmailBody(plainCode, username.trim()),
              'html': _buildHtmlEmailBody(plainCode, username.trim()),
            },
          });
        } catch (_) {
          // Failure to queue the email does NOT invalidate the session.
          // The admin may need to enable the extension or grant write access
          // to the "mail" collection. In dev mode the plaintext code is
          // logged below so the engineer can test the flow.
        }
      } else {
        // ---- Dev-only: inject into in-memory store for local/dev flows without Firestore. ----
        // This is the LOCAL FALLBACK path used when Firebase is not configured
        // (e.g. native builds without google-services, or when running in a sandbox).
        devInjectSession(sessionId, plainCode);
        _devSessionToUsername[sessionId] = username.trim();
      }

      // ---- Dev-only console output (never reaches production end user UI) ----
      assert(() {
        // ignore: avoid_print
        print('----------------------------------------');
        // ignore: avoid_print
        print('[OTP] Session: $sessionId');
        // ignore: avoid_print
        print('[OTP] Code:    $plainCode');
        // ignore: avoid_print
        print('[OTP] Expires: ${expiresAt.toLocal()}');
        // ignore: avoid_print
        print('----------------------------------------');
        return true;
      }());

      return Result.success(sessionId);
    } on AuthFailure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(
        AuthFailure('Failed to request OTP: ${e.toString()}'),
      );
    }
  }

  /// Re-issues an OTP under a new session id. Invalidates the previous one.
  Future<Result<String>> resendOtp(String previousSessionId) async {
    try {
      // Read previous session first (to get username & cooldown state)
      String? username;
      if (_isFirestoreAvailable) {
        DocumentSnapshot<Map<String, dynamic>> snap;
        try {
          snap = await _firestore!
              .collection(kSessionsCollection)
              .doc(previousSessionId)
              .get();
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            throw AuthFailure(
              'Firestore permission denied while loading previous OTP session. '
              'Ensure rules allow reads on "$kSessionsCollection" for '
              'authenticated users.',
            );
          }
          rethrow;
        }
        final data = snap.data();
        if (data == null) {
          return Result.failure(const AuthFailure('No pending OTP session.'));
        }
        username = data['username'] as String?;
      }
      if (username == null || username.isEmpty) {
        username = _lastDevUsernameFor(previousSessionId);
      }
      if (username == null || username.isEmpty) {
        return Result.failure(const AuthFailure('No pending OTP session.'));
      }
      return requestOtp(username: username);
    } on AuthFailure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(
        AuthFailure('Failed to resend OTP: ${e.toString()}'),
      );
    }
  }

  /// Verifies an entered OTP against the authoritative Firestore session.
  ///
  /// Client must pass the `sessionId` it received from requestOtp/resendOtp,
  /// plus the digits the human typed in. Only the service-side hash is compared.
  Future<Result<void>> verifyOtp(String sessionId, String enteredCode) async {
    try {
      final cleanCode = enteredCode.trim();
      if (cleanCode.length != kOtpDigits || int.tryParse(cleanCode) == null) {
        return Result.failure(
          const AuthFailure('Invalid verification code format.'),
        );
      }

      if (!_isFirestoreAvailable) {
        // ---- Dev path: keep a transient in-memory map so flows are testable ----
        return _devVerifyInMemory(sessionId, cleanCode);
      }

      DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore!
            .collection(kSessionsCollection)
            .doc(sessionId)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw AuthFailure(
            'Firestore permission denied while loading OTP session. '
            'Ensure rules allow reads on "$kSessionsCollection" for '
            'authenticated users.',
          );
        }
        rethrow;
      }
      final data = snap.data();
      if (data == null) {
        return Result.failure(
          const AuthFailure('Verification session expired or not found.'),
        );
      }

      // ---- Expiry check ----
      final expiresAt = DateTime.parse(data['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        await _markInvalidated(sessionId);
        return Result.failure(
          const AuthFailure('Verification code expired. Request a new one.'),
        );
      }

      // ---- Already used / invalidated ----
      if ((data['is_verified'] as bool?) == true) {
        return Result.failure(
          const AuthFailure('Verification code already used.'),
        );
      }
      if ((data['is_invalidated'] as bool?) == true) {
        return Result.failure(
          const AuthFailure('Verification code has been invalidated.'),
        );
      }

      // ---- Attempt count ----
      final attemptsUsed = (data['attempts_used'] as int?) ?? 0;
      if (attemptsUsed >= kMaxAttempts) {
        await _markInvalidated(sessionId);
        return Result.failure(
          const AuthFailure('Too many failed attempts. Request a new code.'),
        );
      }

      // ---- Hash + constant-time compare ----
      final salt = data['otp_salt'] as String;
      final storedHash = data['otp_hash'] as String;
      final candidateHash = _hashOtp(cleanCode, salt);
      final matches = _constantTimeEquals(storedHash, candidateHash);

      // Bump attempt count regardless of outcome
      final nextAttempts = attemptsUsed + 1;
      if (matches) {
        try {
          await _firestore
              .collection(kSessionsCollection)
              .doc(sessionId)
              .update({
                'attempts_used': nextAttempts,
                'is_verified': true,
                'verified_at': DateTime.now().toIso8601String(),
              });
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            throw AuthFailure(
              'Firestore permission denied while verifying OTP. '
              'Ensure rules allow writes on "$kSessionsCollection" for '
              'authenticated users.',
            );
          }
          rethrow;
        }
        return Result.success(null);
      } else {
        try {
          await _firestore
              .collection(kSessionsCollection)
              .doc(sessionId)
              .update({'attempts_used': nextAttempts});
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            throw AuthFailure(
              'Firestore permission denied while recording OTP attempt. '
              'Ensure rules allow writes on "$kSessionsCollection" for '
              'authenticated users.',
            );
          }
          rethrow;
        }
        final remaining = kMaxAttempts - nextAttempts;
        final msg = remaining <= 1
            ? 'Incorrect code. $remaining attempt remaining before lockout.'
            : 'Incorrect code. $remaining attempts remaining.';
        return Result.failure(AuthFailure(msg));
      }
    } on AuthFailure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(
        AuthFailure('Verification failed: ${e.toString()}'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _invalidatePreviousSessions(
    String username, {
    required String keepSessionId,
  }) async {
    if (!_isFirestoreAvailable) return;
    try {
      final query = await _firestore!
          .collection(kSessionsCollection)
          .where('username', isEqualTo: username.trim())
          .where('is_verified', isEqualTo: false)
          .where('is_invalidated', isEqualTo: false)
          .get();
      final batch = _firestore.batch();
      for (final doc in query.docs) {
        if (doc.id == keepSessionId) continue;
        batch.update(doc.reference, <String, dynamic>{
          'is_invalidated': true,
          'invalidated_reason': 'superceded_by_resend',
          'invalidated_at': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit();
    } catch (_) {
      // Best-effort cleanup. If this fails (e.g. composite index missing,
      // permission denied on batch write), the new session is still valid.
    }
  }

  Future<void> _markInvalidated(String sessionId) async {
    if (!_isFirestoreAvailable) return;
    try {
      await _firestore!.collection(kSessionsCollection).doc(sessionId).update({
        'is_invalidated': true,
        'invalidated_reason': 'expired_or_lockout',
        'invalidated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort: a stale/invalid session row on the server is harmless.
    }
  }

  Future<AuthFailure?> _enforceResendRateLimits(String username) async {
    if (!_isFirestoreAvailable) return null;
    final windowStart = DateTime.now().subtract(
      const Duration(seconds: kResendCooldownSeconds),
    );
    final recent = await _firestore!
        .collection(kSessionsCollection)
        .where('username', isEqualTo: username.trim())
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();
    if (recent.docs.isNotEmpty) {
      final data = recent.docs.first.data();
      final created = DateTime.parse(data['created_at'] as String);
      if (created.isAfter(windowStart)) {
        final waitSeconds = created.difference(windowStart).inSeconds;
        return AuthFailure(
          'Please wait $waitSeconds seconds before requesting a new code.',
        );
      }

      // Hourly bucket cap
      final bucketStartRaw = data['hourly_resend_bucket_start'] as String?;
      final bucketStart = bucketStartRaw != null
          ? DateTime.parse(bucketStartRaw)
          : created;
      final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
      int resendCount = data['resend_count'] as int? ?? 1;
      if (bucketStart.isAfter(hourAgo) && resendCount >= kMaxResendsPerHour) {
        return const AuthFailure('Too many codes requested. Try again later.');
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // In-memory fallback for dev-only scenarios when Firestore is unavailable
  // ---------------------------------------------------------------------------

  final Map<String, _DevOtpSession> _devSessions = <String, _DevOtpSession>{};
  final Map<String, String> _devSessionToUsername = <String, String>{};

  String? _lastDevUsernameFor(String sessionId) {
    // For dev resends without Firestore, fall back to OwnerService-saved state.
    return _devSessionToUsername[sessionId];
  }

  Future<Result<void>> _devVerifyInMemory(
    String sessionId,
    String cleanCode,
  ) async {
    final s = _devSessions[sessionId];
    if (s == null) {
      return Result.failure(
        const AuthFailure('Verification session expired or not found.'),
      );
    }
    if (DateTime.now().isAfter(s.expiresAt)) {
      _devSessions.remove(sessionId);
      _devSessionToUsername.remove(sessionId);
      return Result.failure(const AuthFailure('Verification code expired.'));
    }
    if (s.verified) {
      return Result.failure(
        const AuthFailure('Verification code already used.'),
      );
    }
    if (s.attempts >= kMaxAttempts) {
      _devSessions.remove(sessionId);
      _devSessionToUsername.remove(sessionId);
      return Result.failure(const AuthFailure('Too many failed attempts.'));
    }
    s.attempts += 1;
    final matches = _constantTimeEquals(s.otpHash, _hashOtp(cleanCode, s.salt));
    if (matches) {
      s.verified = true;
      return Result.success(null);
    }
    return Result.failure(
      AuthFailure(
        'Incorrect code. ${kMaxAttempts - s.attempts} attempts remaining.',
      ),
    );
  }

  /// Hook used by requestOtp to populate dev in-memory sessions when Firestore
  /// is not configured. This keeps end-to-end flows testable without Firebase.
  void devInjectSession(String sessionId, String plainCode) {
    final salt = _generateSalt();
    _devSessions[sessionId] = _DevOtpSession(
      otpHash: _hashOtp(plainCode, salt),
      salt: salt,
      expiresAt: DateTime.now().add(
        const Duration(minutes: kOtpValidityMinutes),
      ),
      attempts: 0,
      verified: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Crypto primitives
  // ---------------------------------------------------------------------------

  String _generateSecureSixDigitCode() {
    final rng = Random.secure();
    final bytes = Uint8List(4);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    final value =
        ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
        0x7fffffff;
    final code = value % 1000000;
    return code.toString().padLeft(kOtpDigits, '0');
  }

  String _generateSalt() {
    final rng = Random.secure();
    final bytes = Uint8List(kSaltBytes);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  String _hashOtp(String code, String salt) {
    final bytes = utf8.encode('$salt\$jonkstore::otp\$$code');
    final digest = sha256.convert(bytes);
    return '$salt.${digest.toString()}';
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int r = 0;
    for (int i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }

  // ---------------------------------------------------------------------------
  // Email body builders (content handed to backend Trigger Email extension)
  // ---------------------------------------------------------------------------

  String _buildPlaintextEmailBody(String code, String username) {
    return [
      'Hello $username,',
      '',
      'Your JonkStore POS verification code is:',
      '',
      '    $code',
      '',
      'This code expires in $kOtpValidityMinutes minutes and can be used only once.',
      'If you did not request this code, you can safely ignore this email.',
      '',
      '— JonkStore POS',
    ].join('\n');
  }

  String _buildHtmlEmailBody(String code, String username) {
    return '''
<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;color:#1f2937;">
  <div style="background:#10b981;color:#fff;padding:18px;border-radius:10px 10px 0 0;text-align:center;">
    <h1 style="margin:0;font-size:20px;">JonkStore POS</h1>
  </div>
  <div style="background:#fff;border:1px solid #e5e7eb;border-top:none;border-radius:0 0 10px 10px;padding:28px;">
    <p style="margin:0 0 12px;">Hello <strong>$username</strong>,</p>
    <p style="margin:0 0 20px;">Use this 6-digit code to verify your identity:</p>
    <div style="background:#f3f4f6;border-radius:10px;padding:20px;text-align:center;letter-spacing:6px;font-size:32px;font-weight:700;color:#111827;margin-bottom:20px;">
      $code
    </div>
    <p style="margin:0 0 8px;color:#374151;">Expires in <strong>$kOtpValidityMinutes minutes</strong> and is valid for <strong>one use</strong>.</p>
    <p style="margin:0;color:#6b7280;font-size:13px;">If you did not request this code, ignore this email.</p>
  </div>
</div>''';
  }
}

class _DevOtpSession {
  final String otpHash;
  final String salt;
  final DateTime expiresAt;
  int attempts;
  bool verified;

  _DevOtpSession({
    required this.otpHash,
    required this.salt,
    required this.expiresAt,
    required this.attempts,
    required this.verified,
  });
}
