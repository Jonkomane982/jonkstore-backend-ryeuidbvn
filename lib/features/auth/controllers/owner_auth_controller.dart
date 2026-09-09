import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/owner_profile.dart';
import 'package:jonkstore/core/services/owner_service.dart';
import 'package:jonkstore/providers/owner_providers.dart';

class OwnerAuthState {
  final bool isLoading;
  final String? errorMessage;
  final OwnerProfile? profile;

  final bool isLoginSuccess;
  final bool isVerified;
  final bool isPasswordResetSent;
  
  // ---- OTP & 2FA State ----
  final bool isOtpSent;
  final bool isOtpVerified;
  final bool isLoginOtpPending; // NEW: Distinguishes Login from Registration
  final bool isRegistrationStarted;
  final bool onboardingNeedsBusinessSetup;

  OwnerAuthState({
    this.isLoading = false,
    this.errorMessage,
    this.profile,
    this.isLoginSuccess = false,
    this.isVerified = false,
    this.isPasswordResetSent = false,
    this.isOtpSent = false,
    this.isOtpVerified = false,
    this.isLoginOtpPending = false,
    this.isRegistrationStarted = false,
    this.onboardingNeedsBusinessSetup = false,
  });

  OwnerAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    OwnerProfile? profile,
    bool? isLoginSuccess,
    bool? isVerified,
    bool? isPasswordResetSent,
    bool? isOtpSent,
    bool? isOtpVerified,
    bool? isLoginOtpPending,
    bool? isRegistrationStarted,
    bool? onboardingNeedsBusinessSetup,
    bool clearErrorMessage = false,
  }) {
    return OwnerAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : errorMessage,
      profile: profile ?? this.profile,
      isLoginSuccess: isLoginSuccess ?? this.isLoginSuccess,
      isVerified: isVerified ?? this.isVerified,
      isPasswordResetSent: isPasswordResetSent ?? this.isPasswordResetSent,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isOtpVerified: isOtpVerified ?? this.isOtpVerified,
      isLoginOtpPending: isLoginOtpPending ?? this.isLoginOtpPending,
      isRegistrationStarted: isRegistrationStarted ?? this.isRegistrationStarted,
      onboardingNeedsBusinessSetup: onboardingNeedsBusinessSetup ?? this.onboardingNeedsBusinessSetup,
    );
  }
}

class OwnerAuthController extends StateNotifier<OwnerAuthState> {
  final OwnerService _ownerService;

  OwnerAuthController(this._ownerService) : super(OwnerAuthState());

  /// Google Sign-In: Direct access for authorized owner
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null, clearErrorMessage: true);
    final result = await _ownerService.signInWithGoogle();
    result.fold(
      (profile) => state = state.copyWith(isLoading: false, profile: profile, isLoginSuccess: true),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Start Registration: Verifies credentials then asks for OTP
  Future<void> startRegistration({required String username, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, clearErrorMessage: true);
    final result = await _ownerService.startOwnerRegistration(username: username, password: password);
    result.fold(
      (_) => state = state.copyWith(isLoading: false, isRegistrationStarted: true, isLoginOtpPending: false),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Start Login: Verifies credentials then triggers OTP flow (2FA)
  Future<void> login({required String username, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, clearErrorMessage: true);
    final result = await _ownerService.startOwnerLogin(username: username, password: password);
    
    result.fold(
      (_) async {
        // Password correct, now request OTP for 2FA
        final otpResult = await _ownerService.requestOtpCode();
        otpResult.fold(
          (_) => state = state.copyWith(isLoading: false, isOtpSent: true, isLoginOtpPending: true),
          (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
        );
      },
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Request code (Shared by Login and Registration)
  Future<void> requestOtp() async {
    state = state.copyWith(isLoading: true, errorMessage: null, clearErrorMessage: true);
    final result = await _ownerService.requestOtpCode();
    result.fold(
      (_) => state = state.copyWith(isLoading: false, isOtpSent: true),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Verify OTP: Decides whether to go to Dashboard or Business Setup
  Future<void> verifyOtp(String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null, clearErrorMessage: true);
    final result = await _ownerService.verifyOtp(code);

    if (result.isSuccess) {
      if (state.isLoginOtpPending) {
        // Finalize Login
        final syncResult = await _ownerService.finalizeLoginSync();
        syncResult.fold(
          (profile) => state = state.copyWith(isLoading: false, isOtpVerified: true, isLoginSuccess: true, profile: profile),
          (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
        );
      } else {
        // Registration successful, proceed to setup
        state = state.copyWith(isLoading: false, isOtpVerified: true, onboardingNeedsBusinessSetup: true);
      }
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.failure.message);
    }
  }

  /// Account Recovery: Request Reset Link
  Future<void> forgotPassword() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _ownerService.requestPasswordReset();
    result.fold(
      (_) => state = state.copyWith(isLoading: false, isPasswordResetSent: true),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  void resetOnboarding() {
    state = OwnerAuthState();
  }
}

final ownerAuthControllerProvider = StateNotifierProvider<OwnerAuthController, OwnerAuthState>((ref) {
  return OwnerAuthController(ref.watch(ownerServiceProvider));
});
