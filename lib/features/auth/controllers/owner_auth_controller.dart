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
  final bool isPasswordChangeSuccess;

  // ---- Onboarding (first-time registration) state ----
  final bool isRegistrationStarted;
  final bool isOtpSent;
  final bool isOtpVerified;
  final String? pendingUsername;
  final String? otpSessionId;
  final bool onboardingNeedsBusinessSetup;

  OwnerAuthState({
    this.isLoading = false,
    this.errorMessage,
    this.profile,
    this.isLoginSuccess = false,
    this.isVerified = false,
    this.isPasswordResetSent = false,
    this.isPasswordChangeSuccess = false,
    this.isRegistrationStarted = false,
    this.isOtpSent = false,
    this.isOtpVerified = false,
    this.pendingUsername,
    this.otpSessionId,
    this.onboardingNeedsBusinessSetup = false,
  });

  OwnerAuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    OwnerProfile? profile,
    bool? isLoginSuccess,
    bool? isVerified,
    bool? isPasswordResetSent,
    bool? isPasswordChangeSuccess,
    bool? isRegistrationStarted,
    bool? isOtpSent,
    bool? isOtpVerified,
    String? pendingUsername,
    String? otpSessionId,
    bool? onboardingNeedsBusinessSetup,
    bool clearErrorMessage = false,
  }) {
    return OwnerAuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : errorMessage,
      profile: profile ?? this.profile,
      isLoginSuccess: isLoginSuccess ?? this.isLoginSuccess,
      isVerified: isVerified ?? this.isVerified,
      isPasswordResetSent:
          isPasswordResetSent ?? this.isPasswordResetSent,
      isPasswordChangeSuccess:
          isPasswordChangeSuccess ?? this.isPasswordChangeSuccess,
      isRegistrationStarted:
          isRegistrationStarted ?? this.isRegistrationStarted,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isOtpVerified: isOtpVerified ?? this.isOtpVerified,
      pendingUsername: pendingUsername ?? this.pendingUsername,
      otpSessionId: otpSessionId ?? this.otpSessionId,
      onboardingNeedsBusinessSetup:
          onboardingNeedsBusinessSetup ?? this.onboardingNeedsBusinessSetup,
    );
  }
}

class OwnerAuthController extends StateNotifier<OwnerAuthState> {
  final OwnerService _ownerService;

  OwnerAuthController(this._ownerService) : super(OwnerAuthState());

  // ---------------------------------------------------------------------------
  // Google Sign In
  // ---------------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearErrorMessage: true,
    );

    final result = await _ownerService.signInWithGoogle();

    result.fold(
      (profile) => state = state.copyWith(
        isLoading: false,
        profile: profile,
        isLoginSuccess: true,
        isVerified: profile.isVerified,
      ),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // First-Time Onboarding Step 1: Create Firebase identity (no DB write yet)
  // ---------------------------------------------------------------------------

  Future<void> startRegistration({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearErrorMessage: true,
    );
    final trimmedUser = username.trim();
    final result = await _ownerService.startOwnerRegistration(
      username: trimmedUser,
      password: password,
    );

    result.fold(
      (_) => state = state.copyWith(
        isLoading: false,
        isRegistrationStarted: true,
        pendingUsername: trimmedUser,
      ),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
        isRegistrationStarted: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Onboarding Step 2: Request backend OTP (no mailto / no Gmail compose)
  // ---------------------------------------------------------------------------

  Future<void> requestOtp() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearErrorMessage: true,
      isOtpSent: false,
    );

    final result = await _ownerService.requestOtpCode();

    result.fold(
      (sessionId) => state = state.copyWith(
        isLoading: false,
        isOtpSent: true,
        otpSessionId: sessionId,
      ),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
        isOtpSent: false,
      ),
    );
  }

  Future<void> resendOtp() async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearErrorMessage: true,
      isOtpSent: false,
    );

    final result = await _ownerService.resendOtpCode();

    result.fold(
      (_) => state = state.copyWith(
        isLoading: false,
        isOtpSent: true,
      ),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
        isOtpSent: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Onboarding Step 3: Verify OTP. On success → Business Setup
  // ---------------------------------------------------------------------------

  Future<void> verifyOtp(String code) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearErrorMessage: true,
    );

    final result = await _ownerService.verifyOtp(code.trim());

    result.fold(
      (_) => state = state.copyWith(
        isLoading: false,
        isOtpVerified: true,
        onboardingNeedsBusinessSetup: true,
      ),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
        isOtpVerified: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DAILY LOGIN — Username + Password only (no OTP, no email input)
  // ---------------------------------------------------------------------------

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      clearErrorMessage: true,
    );

    final result = await _ownerService.loginOwner(
      username: username.trim(),
      password: password,
    );

    result.fold(
      (profile) => state = state.copyWith(
        isLoading: false,
        profile: profile,
        isLoginSuccess: true,
        isVerified: profile.isVerified,
      ),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Email verification status polling (used by legacy verify-email screen)
  // ---------------------------------------------------------------------------

  Future<void> checkVerification() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _ownerService.checkVerificationStatus();

    result.fold(
      (isVerified) =>
          state = state.copyWith(isLoading: false, isVerified: isVerified),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  Future<void> resendVerification() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _ownerService.resendVerificationEmail();

    result.fold(
      (_) => state = state.copyWith(isLoading: false),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Password management
  // ---------------------------------------------------------------------------

  Future<void> forgotPassword({String? email}) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isPasswordResetSent: false,
    );
    final result = await _ownerService.sendPasswordResetEmail(email: email);

    result.fold(
      (_) =>
          state = state.copyWith(isLoading: false, isPasswordResetSent: true),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
        isPasswordResetSent: false,
      ),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isPasswordChangeSuccess: false,
    );
    final result = await _ownerService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    result.fold(
      (_) => state = state.copyWith(
        isLoading: false,
        isPasswordChangeSuccess: true,
      ),
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
        isPasswordChangeSuccess: false,
      ),
    );
  }

  /// Resets onboarding OTP state back to "enter username/password".
  void resetOnboarding() {
    state = OwnerAuthState(profile: state.profile);
  }
}

final ownerAuthControllerProvider =
    StateNotifierProvider<OwnerAuthController, OwnerAuthState>((ref) {
  return OwnerAuthController(ref.watch(ownerServiceProvider));
});
