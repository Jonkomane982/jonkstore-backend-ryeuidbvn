import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_providers.dart';
import '../domain/models/user.dart';
import 'user_session.dart';
import '../../repositories/auth_repository.dart';

/// Manages the high-level user session and authentication lifecycle.
class SessionManager extends StateNotifier<UserSession> {
  final AuthRepository _authRepository;

  SessionManager(this._authRepository) : super(UserSession());

  /// Initializes the session by listening to auth state changes.
  void initialize() {
    _authRepository.authStateChanges.listen((User? user) {
      if (user != null) {
        state = state.copyWith(
          user: user,
          isEmailVerified: _authRepository.isEmailVerified,
        );
      } else {
        state = UserSession();
      }
    });
  }

  /// Refreshes the current session (e.g. to check email verification status).
  Future<void> refreshSession() async {
    await _authRepository.reloadUser();
    state = state.copyWith(isEmailVerified: _authRepository.isEmailVerified);
  }

  /// Signs out and clears the session.
  Future<void> logout() async {
    await _authRepository.signOut();
    state = UserSession();
  }
}

/// Provider for the [SessionManager].
final sessionManagerProvider = StateNotifierProvider<SessionManager, UserSession>((ref) {
  final manager = SessionManager(ref.watch(authRepositoryProvider));
  manager.initialize();
  return manager;
});
