import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:jonkstore/core/config/app_owner.dart';
import 'package:jonkstore/core/domain/models/user.dart';
import 'package:jonkstore/core/domain/enums/user_role.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'auth_repository.dart';
import 'user_repository.dart';

class FirebaseAuthRepositoryImpl implements AuthRepository {
  final UserRepository _userRepository;
  fb.FirebaseAuth? _firebaseAuth;

  FirebaseAuthRepositoryImpl({
    fb.FirebaseAuth? firebaseAuth,
    required UserRepository userRepository,
  }) : _firebaseAuth = firebaseAuth,
       _userRepository = userRepository;

  fb.FirebaseAuth? get _auth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseAuth = fb.FirebaseAuth.instance;
      }
    } catch (_) {}
    return _firebaseAuth;
  }

  bool get _isFirebaseReady => _auth != null;

  @override
  Stream<User?> get authStateChanges {
    if (!_isFirebaseReady) {
      if (kDebugMode) {
        print(
          'JonkStore: [Auth] Firebase not initialized — using local auth state.',
        );
      }
      return Stream<User?>.value(null);
    }
    return _auth!.authStateChanges().transform(
      StreamTransformer<fb.User?, User?>.fromHandlers(
        handleData: (fbUser, sink) async {
          if (fbUser == null) {
            sink.add(null);
            return;
          }
          final result = await _userRepository.findById(fbUser.uid);
          result.fold((user) => sink.add(user), (_) => sink.add(null));
        },
        handleError: (e, _, sink) {
          if (kDebugMode) print('JonkStore: [Auth] authState error: $e');
          sink.add(null);
        },
      ),
    );
  }

  @override
  String? get currentUserId => _auth?.currentUser?.uid;

  @override
  bool get isEmailVerified => _auth?.currentUser?.emailVerified ?? false;

  @override
  Future<Result<User>> signIn(String email, String password) async {
    // Fallback for iOS/Desktop if Firebase is not configured or fails
    if (!_isFirebaseReady && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.windows)) {
       if (kDebugMode) print('JonkStore: [Auth] Firebase unavailable. Attempting local fallback login.');
       // Check against AppOwner for local dev bypass
       if (email.toLowerCase() == AppOwner.ownerEmail.toLowerCase()) {
         final user = User(
           id: 'local_owner_id',
           name: 'App Owner (Local)',
           email: email,
           role: UserRole.owner,
           createdAt: DateTime.now(),
           updatedAt: DateTime.now(),
           syncStatus: SyncStatus.synced,
         );
         return Result.success(user);
       }
    }

    if (!_isFirebaseReady) {
      return Result.failure(
        const AuthFailure(
          'Firebase is not initialized. Check network or platform config.',
        ),
      );
    }

    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return Result.failure(
          const AuthFailure('User not found after sign in'),
        );
      }

      final userResult = await _userRepository.findById(credential.user!.uid);
      return userResult.fold((user) {
        if (user != null) return Result.success(user);
        return Result.failure(
          const AuthFailure('User record not found in database'),
        );
      }, (failure) => Result.failure(failure));
    } on fb.FirebaseAuthException catch (e) {
      return Result.failure(AuthFailure(e.message ?? 'Authentication failed'));
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<User>> signUp(
    String email,
    String password,
    String name,
  ) async {
    if (!_isFirebaseReady) {
      return Result.failure(
        const AuthFailure('Firebase is not initialized.'),
      );
    }
    try {
      if (email.trim().toLowerCase() != AppOwner.ownerEmail.toLowerCase()) {
        return Result.failure(
          const AuthFailure(
            'Registration is restricted. Only the app owner may register.',
          ),
        );
      }

      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return Result.failure(const AuthFailure('User creation failed'));
      }

      final newUser = User(
        id: credential.user!.uid,
        name: name,
        email: email,
        role: UserRole.owner,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.synced,
      );

      await _userRepository.create(newUser);
      return Result.success(newUser);
    } on fb.FirebaseAuthException catch (e) {
      return Result.failure(AuthFailure(e.message ?? 'Sign up failed'));
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    if (!_isFirebaseReady) return Result.success(null);
    try {
      await _auth!.signOut();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> resetPassword(String email) async {
    if (!_isFirebaseReady) return Result.failure(const AuthFailure('Firebase not ready'));
    try {
      await _auth!.sendPasswordResetEmail(email: email);
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    if (!_isFirebaseReady) return Result.failure(const AuthFailure('Firebase not ready'));
    try {
      await _auth!.currentUser?.sendEmailVerification();
      return Result.success(null);
    } catch (e) {
      return Result.failure(AuthFailure(e.toString()));
    }
  }

  @override
  Future<void> reloadUser() async {
    if (!_isFirebaseReady) return;
    try {
      await _auth!.currentUser?.reload();
    } catch (_) {}
  }
}
