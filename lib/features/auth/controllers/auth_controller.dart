import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_owner.dart';
import '../../../providers/auth_providers.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  AuthState copyWith({bool? isLoading, String? errorMessage, bool? isSuccess}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthController(this._ref) : super(AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final repository = _ref.read(authRepositoryProvider);
    final result = await repository.signIn(email, password);

    result.fold(
      (user) => state = state.copyWith(isLoading: false, isSuccess: true),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  Future<void> register(String email, String password, String name) async {
    if (email.trim().toLowerCase() != AppOwner.ownerEmail.toLowerCase()) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Registration is restricted. Only the app owner may register.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, errorMessage: null);
    final repository = _ref.read(authRepositoryProvider);
    final result = await repository.signUp(email, password, name);

    result.fold(
      (user) {
        repository.sendEmailVerification();
        state = state.copyWith(isLoading: false, isSuccess: true);
      },
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final repository = _ref.read(authRepositoryProvider);
    final result = await repository.resetPassword(email);

    result.fold(
      (_) => state = state.copyWith(isLoading: false, isSuccess: true),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  void reset() {
    state = AuthState();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref);
  },
);
