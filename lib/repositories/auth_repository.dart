import '../core/domain/models/user.dart';
import '../core/network/result.dart';

/// Interface for Authentication operations.
abstract class AuthRepository {
  /// Returns the currently authenticated user, if any.
  Stream<User?> get authStateChanges;

  /// Signs in a user with email and password.
  Future<Result<User>> signIn(String email, String password);

  /// Signs up a new user with email and password.
  Future<Result<User>> signUp(String email, String password, String name);

  /// Signs out the current user.
  Future<Result<void>> signOut();

  /// Sends a password reset email.
  Future<Result<void>> resetPassword(String email);

  /// Sends an email verification link to the current user.
  Future<Result<void>> sendEmailVerification();

  /// Checks if the current user's email is verified.
  bool get isEmailVerified;

  /// Returns the current user's ID if authenticated.
  String? get currentUserId;

  /// Reloads the current user to get updated information (e.g. email verification status).
  Future<void> reloadUser();
}
