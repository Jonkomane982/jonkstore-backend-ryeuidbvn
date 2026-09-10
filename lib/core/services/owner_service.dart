import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:jonkstore/core/services/password_service.dart';
import 'package:jonkstore/core/network/api_client.dart';

/// Temporary in-memory state captured during registration.
class _PendingRegistration {
  final String username;
  final String email;
  final String passwordHash;
  final String firebaseUid;
  _PendingRegistration({
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.firebaseUid,
  });
}

/// Service for User Authentication and Account Management.
class OwnerService {
  final FirebaseAuth _firebaseAuth;
  final OwnerRepository _ownerRepository;
  final PasswordService _passwordService;
  final ApiClient _apiClient;

  _PendingRegistration? _pendingReg;
  String? _lastLoginEmail;

  OwnerService(
    this._firebaseAuth,
    this._ownerRepository,
    this._apiClient,
  ) : _passwordService = PasswordService();

  bool get _firebaseInitialized => Firebase.apps.isNotEmpty;

  /// Start Registration: Open to any user email.
  Future<Result<void>> startRegistration({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final passwordHash = _passwordService.hashPassword(password);
      UserCredential cred;

      try {
        cred = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // If account exists, verify password by signing in.
          cred = await _firebaseAuth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } else {
          return Result.failure(AuthFailure(e.message ?? 'Authentication failed'));
        }
      }

      _pendingReg = _PendingRegistration(
        username: username.trim(),
        email: email.trim(),
        passwordHash: passwordHash,
        firebaseUid: cred.user!.uid,
      );

      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure('System error: ${e.toString()}'));
    }
  }

  /// Start Login: Open to any user email.
  Future<Result<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      final idToken = await cred.user!.getIdToken();
      
      // Call backend to check status and trigger OTP
      final response = await _apiClient.post('auth/login', data: {'idToken': idToken});
      
      _lastLoginEmail = email.trim();
      return Result.success(response.data);
    } on FirebaseAuthException catch (e) {
      return Result.failure(const AuthFailure('Invalid email or password.'));
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  /// Triggers a verification code to the SUPER ADMIN email for authorization.
  Future<Result<void>> requestAuthorizationCode() async {
    try {
      // Backend is configured to send the code to jonkomanelesoetsa@gmail.com
      await _apiClient.post('auth/owner/request-otp', data: {
        'email': _lastLoginEmail ?? _pendingReg?.email ?? 'Owner',
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  /// Verifies the code entered by the user (which was sent to the Admin).
  Future<Result<void>> verifyAuthorizationCode(String code) async {
    try {
      await _apiClient.post('auth/owner/verify-otp', data: {
        'email': _lastLoginEmail ?? _pendingReg?.email ?? '',
        'otpCode': code.trim(),
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(const AuthFailure('Invalid or expired code.'));
    }
  }

  /// Finalizes the session and synchronizes profile data.
  Future<Result<OwnerProfile>> finalizeAuth() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return Result.failure(const AuthFailure('Session expired'));

      final idToken = await user.getIdToken();
      // This second call to login will now return the profile because OTP is verified on server
      final response = await _apiClient.post('auth/login', data: {'idToken': idToken});
      
      final profile = OwnerProfile.fromJson(response.data['data']['user']);
      await _ownerRepository.saveProfile(profile);

      return Result.success(profile);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  /// Account Recovery: Sends reset link to the specified email via Backend.
  Future<Result<void>> forgotPassword(String email) async {
    try {
      await _apiClient.post('auth/owner/forgot-password', data: {
        'email': email.trim().toLowerCase(),
      });
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  Future<Result<OwnerProfile>> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return Result.failure(const AuthFailure('Sign-in cancelled'));

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user!.getIdToken();

      final response = await _apiClient.post('auth/login', data: {'idToken': idToken});
      
      if (response.data['data']?['pending'] == true) {
        return Result.failure(const AuthFailure('Account pending activation.'));
      }

      final profile = OwnerProfile.fromJson(response.data['data']['user']);
      await _ownerRepository.saveProfile(profile);

      return Result.success(profile);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  // --- Super Admin Capabilities ---

  Future<Result<List<OwnerProfile>>> listAllAccounts() async {
    try {
      final res = await _apiClient.get('auth/users');
      final list = (res.data['data']['items'] as List).map((j) => OwnerProfile.fromJson(j)).toList();
      return Result.success(list);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  Future<Result<void>> updateAccountStatus(String userId, String status) async {
    try {
      await _apiClient.patch('auth/users/$userId/status', data: {'status': status});
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  Future<Result<void>> deleteAccount(String userId) async {
    try {
      await _apiClient.delete('auth/users/$userId');
      return Result.success(null);
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
      return Result.success(profile);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  Future<Result<bool>> checkVerificationStatus() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return Result.success(false);
    await user.reload();
    return Result.success(_firebaseAuth.currentUser?.emailVerified ?? false);
  }
}
