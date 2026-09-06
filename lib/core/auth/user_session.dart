import '../domain/models/user.dart';

/// Represents the current active user session.
class UserSession {
  final User? user;
  final bool isEmailVerified;

  UserSession({
    this.user,
    this.isEmailVerified = false,
  });

  bool get isAuthenticated => user != null;

  UserSession copyWith({
    User? user,
    bool? isEmailVerified,
  }) {
    return UserSession(
      user: user ?? this.user,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}
