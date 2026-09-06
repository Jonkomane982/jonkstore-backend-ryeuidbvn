import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:jonkstore/core/config/app_owner.dart';
import 'package:jonkstore/core/domain/models/owner_profile.dart';
import 'package:jonkstore/core/domain/enums/user_role.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/repositories/owner_repository.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/firebase_options.dart';
import 'package:jonkstore/core/services/password_service.dart';
import 'package:jonkstore/core/services/otp_service.dart';
import 'package:jonkstore/core/network/api_client.dart';

/// Temporary in-memory state captured during first-time registration.
class _PendingRegistration {
  final String username;
  final String passwordHash;
  final String firebaseUid;
  final String email;
  final DateTime createdAt;

  _PendingRegistration({
    required this.username,
    required this.passwordHash,
    required this.firebaseUid,
    required this.email,
  }) : createdAt = DateTime.now();
}

/// Owner authentication orchestrator.
class OwnerService {
  final FirebaseAuth? _firebaseAuth;
  final OwnerRepository _ownerRepository;
  final PasswordService _passwordService;
  final OtpService _otpService;
  final ApiClient _apiClient;

  _PendingRegistration? _pendingReg;
  String? _lastOtpSessionId;
  String? _lastRegistrationUsername;

  OwnerService(
    this._firebaseAuth,
    this._ownerRepository,
    this._otpService,
    this._apiClient, {
    PasswordService? passwordService,
  }) : _passwordService = passwordService ?? PasswordService();

  static bool get _firebaseConfigIsPlaceholder {
    try {
      final opts = DefaultFirebaseOptions.currentPlatform;
      return opts.apiKey == 'placeholder' ||
          opts.apiKey.contains('REPLACE_ME');
    } catch (_) {
      return true;
    }
  }

  bool get _firebaseInitialized => Firebase.apps.isNotEmpty;
  bool get _useDevAuth => _firebaseConfigIsPlaceholder || !_firebaseInitialized;

  static String _devFakeUid(String seed) {
    final bytes = seed.codeUnits;
    return 'dev_${bytes.fold<int>(0, (a, b) => a + b).toString().padLeft(16, '0')}';
  }

  Future<Result<void>> startOwnerRegistration({
    required String username,
    required String password,
  }) async {
    try {
      final passwordHash = _passwordService.hashPassword(password);
      String firebaseUid;

      if (_useDevAuth) {
        firebaseUid = _devFakeUid('${AppOwner.ownerEmail}$username');
      } else {
        final cred = await _signInOrCreateWithRetries(
          create: true,
          email: AppOwner.ownerEmail,
          password: password,
        );
        firebaseUid = cred.user!.uid;
      }

      _pendingReg = _PendingRegistration(
        username: username.trim(),
        passwordHash: passwordHash,
        firebaseUid: firebaseUid,
        email: AppOwner.ownerEmail,
      );
      _lastRegistrationUsername = username.trim();

      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  Future<Result<String>> requestOtpCode() async {
    final who = _pendingReg?.username ?? _lastRegistrationUsername ?? 'Owner';
    final r = await _otpService.requestOtp(username: who);
    r.fold((sid) => _lastOtpSessionId = sid, (_) {});
    return r;
  }

  Future<Result<void>> verifyOtp(String code) async {
    final sid = _lastOtpSessionId;
    if (sid == null) return Result.failure(const AuthFailure('No session'));
    return await _otpService.verifyOtp(sid, code);
  }

  /// Implements Google Sign-In and synchronizes with the JonkStore Backend.
  Future<Result<OwnerProfile>> signInWithGoogle() async {
    try {
      if (_useDevAuth) return Result.failure(const AuthFailure('Dev mode active'));

      final GoogleSignIn googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return Result.failure(const AuthFailure('Cancelled'));

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth!.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception('Firebase Auth failed');

      final idToken = await firebaseUser.getIdToken();

      // 1. Sync with Node.js Backend
      final response = await _apiClient.post('/auth/login', data: {'idToken': idToken});
      
      // 2. Materialize profile from backend data
      final profile = OwnerProfile.fromJson(response.data['data']['user']);
      
      // 3. Save locally to SQLite for offline access
      await _ownerRepository.saveProfile(profile);

      return Result.success(profile);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  Future<Result<OwnerProfile>> loginOwner({
    required String username,
    required String password,
  }) async {
    try {
      if (_useDevAuth) {
        final existingResult = await _ownerRepository.getProfile();
        final existing = existingResult.fold((p) => p, (_) => null);
        if (existing == null) return Result.failure(const AuthFailure('No profile'));
        return Result.success(existing);
      }

      final cred = await _signInOrCreateWithRetries(
        create: false,
        email: AppOwner.ownerEmail,
        password: password,
      );
      
      final idToken = await cred.user!.getIdToken();
      final response = await _apiClient.post('/auth/login', data: {'idToken': idToken});
      
      final profile = OwnerProfile.fromJson(response.data['data']['user']);
      await _ownerRepository.saveProfile(profile);
      
      return Result.success(profile);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  Future<Result<OwnerProfile>> completeOnboardingWithBusiness({
    required String businessId,
    Transaction? txn,
  }) async {
    try {
      final reg = _pendingReg;
      if (reg == null) return Result.failure(const AuthFailure('No pending reg'));

      final profile = OwnerProfile(
        id: const Uuid().v4(),
        businessId: businessId,
        firebaseUid: reg.firebaseUid,
        username: reg.username,
        role: UserRole.owner,
        isVerified: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.synced,
        passwordHash: reg.passwordHash,
      );

      await _ownerRepository.saveProfile(profile, txn: txn);
      _pendingReg = null;
      return Result.success(profile);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  Future<Result<bool>> checkVerificationStatus() async {
    final user = _firebaseAuth?.currentUser;
    if (user == null) return Result.success(false);
    await user.reload();
    return Result.success(_firebaseAuth!.currentUser?.emailVerified ?? false);
  }

  Future<Result<void>> resendVerificationEmail() async {
    await _firebaseAuth?.currentUser?.sendEmailVerification();
    return Result.success(null);
  }

  Future<Result<void>> sendPasswordResetEmail({String? email}) async {
    await _firebaseAuth?.sendPasswordResetEmail(email: AppOwner.ownerEmail);
    return Result.success(null);
  }

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth?.currentUser;
    if (user == null) return Result.failure(const AuthFailure('Not signed in.'));
    await user.updatePassword(newPassword);
    return Result.success(null);
  }

  Future<UserCredential> _signInOrCreateWithRetries({
    required bool create,
    required String email,
    required String password,
  }) async {
    if (create) {
      return await _firebaseAuth!.createUserWithEmailAndPassword(email: email, password: password);
    } else {
      return await _firebaseAuth!.signInWithEmailAndPassword(email: email, password: password);
    }
  }
}
