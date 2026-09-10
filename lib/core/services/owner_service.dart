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

/// Owner authentication orchestrator.
/// Bypasses Firestore for OTPs by using the Node.js Backend as the authoritative source.
class OwnerService {
  final FirebaseAuth? _firebaseAuth;
  final OwnerRepository _ownerRepository;
  final PasswordService _passwordService;
  final ApiClient _apiClient;

  _PendingRegistration? _pendingReg;
  String? _lastRegistrationUsername;

  OwnerService(
    this._firebaseAuth,
    this._ownerRepository,
    this._apiClient, {
    PasswordService? passwordService,
  }) : _passwordService = passwordService ?? PasswordService();

  bool get _firebaseInitialized => Firebase.apps.isNotEmpty;

  /// Handles first-time owner setup or password verification for existing account.
  Future<Result<void>> startOwnerRegistration({
    required String username,
    required String password,
  }) async {
    try {
      final passwordHash = _passwordService.hashPassword(password);

      try {
        final cred = await _signInOrCreateWithRetries(
          create: true,
          email: AppOwner.ownerEmail,
          password: password,
        );
        _capturePendingReg(username, passwordHash, cred.user!.uid);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // SECURITY MASKING: Sign in to verify password, then move to OTP verification.
          try {
            final cred = await _signInOrCreateWithRetries(
              create: false,
              email: AppOwner.ownerEmail,
              password: password,
            );
            _capturePendingReg(username, passwordHash, cred.user!.uid);
          } catch (_) {
            return Result.failure(
              const AuthFailure(
                'Authentication failed. Please check your credentials.',
              ),
            );
          }
        } else {
          return Result.failure(
            const AuthFailure('Registration failed. Please try again.'),
          );
        }
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        const AuthFailure('A technical error occurred. Please try again.'),
      );
    }
  }

  void _capturePendingReg(String username, String hash, String uid) {
    _pendingReg = _PendingRegistration(
      username: username.trim(),
      passwordHash: hash,
      firebaseUid: uid,
      email: AppOwner.ownerEmail,
    );
    _lastRegistrationUsername = username.trim();
  }

  /// REST ROUTE: Trigger Backend to send OTP via SMTP
  Future<Result<String>> requestOtpCode() async {
    try {
      // Relative path 'auth/...' to respect the '/api' prefix in Environment.baseUrl
      await _apiClient.post(
        'auth/owner/request-otp',
        data: {'email': AppOwner.ownerEmail},
      );
      return Result.success('sent');
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  /// REST ROUTE: Verify OTP against Backend
  Future<Result<void>> verifyOtp(String code) async {
    try {
      await _apiClient.post(
        'auth/owner/verify-otp',
        data: {'email': AppOwner.ownerEmail, 'otpCode': code.trim()},
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        const AuthFailure('Invalid or expired verification code.'),
      );
    }
  }

  Future<Result<OwnerProfile>> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null)
        return Result.failure(const AuthFailure('Sign-in cancelled.'));

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth!
          .signInWithCredential(credential);
      final idToken = await userCredential.user!.getIdToken();

      // Sync with Backend
      final response = await _apiClient.post(
        'auth/login',
        data: {'idToken': idToken},
      );

      final profile = OwnerProfile.fromJson(response.data['data']['user']);
      await _ownerRepository.saveProfile(profile);

      return Result.success(profile);
    } catch (e) {
      return Result.failure(
        const AuthFailure(
          'Access denied. Ensure you are using the authorized owner account.',
        ),
      );
    }
  }

  Future<Result<OwnerProfile>> loginOwner({
    required String username,
    required String password,
  }) async {
    try {
      final cred = await _signInOrCreateWithRetries(
        create: false,
        email: AppOwner.ownerEmail,
        password: password,
      );

      final idToken = await cred.user!.getIdToken();
      final response = await _apiClient.post(
        'auth/login',
        data: {'idToken': idToken},
      );

      final profile = OwnerProfile.fromJson(response.data['data']['user']);
      await _ownerRepository.saveProfile(profile);

      return Result.success(profile);
    } catch (e) {
      return Result.failure(const AuthFailure('Invalid username or password.'));
    }
  }

  Future<Result<void>> startOwnerLogin({
    required String username,
    required String password,
  }) async {
    try {
      await _signInOrCreateWithRetries(
        create: false,
        email: AppOwner.ownerEmail,
        password: password,
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        const AuthFailure('Invalid username or password.'),
      );
    }
  }

  Future<Result<OwnerProfile>> finalizeLoginSync() async {
    try {
      final user = _firebaseAuth?.currentUser;
      if (user == null) {
        return Result.failure(const AuthFailure('Session expired.'));
      }
      final idToken = await user.getIdToken();
      final response = await _apiClient.post(
        'auth/login',
        data: {'idToken': idToken},
      );

      final profile = OwnerProfile.fromJson(response.data['data']['user']);
      await _ownerRepository.saveProfile(profile);

      return Result.success(profile);
    } catch (e) {
      return Result.failure(
        const AuthFailure('Failed to sync account data.'),
      );
    }
  }

  Future<Result<void>> requestPasswordReset({String? email}) async {
    return sendPasswordResetEmail(email: email);
  }

  Future<Result<void>> resendOtpCode() async => requestOtpCode();

  Future<Result<bool>> checkVerificationStatus() async {
    final user = _firebaseAuth?.currentUser;
    if (user == null) return Result.success(false);
    await user.reload();
    return Result.success(_firebaseAuth!.currentUser?.emailVerified ?? false);
  }

  Future<Result<void>> resendVerificationEmail() async {
    try {
      await _firebaseAuth?.currentUser?.sendEmailVerification();
      return Result.success(null);
    } catch (e) {
      return Result.failure(const AuthFailure('Action failed.'));
    }
  }

  Future<Result<void>> sendPasswordResetEmail({String? email}) async {
    try {
      final targetEmail = (email ?? AppOwner.ownerEmail).trim().toLowerCase();
      await _apiClient.post(
        '/auth/owner/forgot-password',
        data: {'email': targetEmail},
      );
      return Result.success(null);
    } catch (e) {
      return Result.failure(const AuthFailure('Authentication failed.'));
    }
  }

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _firebaseAuth?.currentUser;
      if (user == null)
        return Result.failure(const AuthFailure('Session expired.'));
      await user.updatePassword(newPassword);
      return Result.success(null);
    } catch (e) {
      return Result.failure(const AuthFailure('Update failed.'));
    }
  }

  Future<Result<OwnerProfile>> completeOnboardingWithBusiness({
    required String businessId,
    Transaction? txn,
  }) async {
    try {
      final reg = _pendingReg;
      if (reg == null)
        return Result.failure(const AuthFailure('Session expired.'));

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
      return Result.success(profile);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  static const int _kAuthMaxRetries = 3;

  Future<UserCredential> _signInOrCreateWithRetries({
    required bool create,
    required String email,
    required String password,
  }) async {
    Object? lastError;
    for (int attempt = 0; attempt < _kAuthMaxRetries; attempt++) {
      try {
        if (create) {
          return await _firebaseAuth!.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          return await _firebaseAuth!.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      } catch (e) {
        lastError = e;
        if (e is FirebaseAuthException) {
          if (e.code == 'email-already-in-use' ||
              e.code == 'wrong-password' ||
              e.code == 'user-not-found') {
            throw e;
          }
        }
      }
      if (attempt < _kAuthMaxRetries - 1) {
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (1 << attempt)),
        );
      }
    }
    throw lastError!;
  }
}

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
