import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/shared/buttons/outline_button.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import '../controllers/owner_auth_controller.dart';

/// OTP verification screen shown during first-time owner onboarding.
///
/// After the user enters the 6-digit code sent to their email via the
/// backend SMTP service, verification is performed server-authoritatively.
/// On success they proceed to Business Setup.
class OwnerVerifyEmailScreen extends ConsumerStatefulWidget {
  const OwnerVerifyEmailScreen({super.key});

  @override
  ConsumerState<OwnerVerifyEmailScreen> createState() =>
      _OwnerVerifyEmailScreenState();
}

class _OwnerVerifyEmailScreenState
    extends ConsumerState<OwnerVerifyEmailScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _canResend = true;
  Timer? _cooldownTimer;
  int _resendCountdown = 0;

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final fn in _otpFocusNodes) {
      fn.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _resendCountdown = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown -= 1;
        if (_resendCountdown <= 0) {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _onVerify() async {
    final code = _otpControllers.map((c) => c.text.trim()).join();
    if (code.length != 6) {
      CustomSnackBar.showError(context, 'Please enter all 6 digits.');
      return;
    }
    await ref.read(ownerAuthControllerProvider.notifier).verifyOtp(code);
    final stateAfter = ref.read(ownerAuthControllerProvider);
    if (!mounted) return;
    if (stateAfter.isOtpVerified) {
      CustomSnackBar.showSuccess(context, 'Verification successful.');
      context.goNamed(RouteNames.businessSetup);
    }
  }

  Future<void> _onResend() async {
    if (!_canResend) return;
    await ref.read(ownerAuthControllerProvider.notifier).resendOtp();
    final stateAfter = ref.read(ownerAuthControllerProvider);
    if (!mounted) return;
    if (stateAfter.isOtpSent) {
      CustomSnackBar.showSuccess(
        context,
        'A new verification code has been emailed to you.',
      );
      _startCooldown();
      for (final c in _otpControllers) {
        c.clear();
      }
      FocusScope.of(context).requestFocus(_otpFocusNodes.first);
    }
  }

  void _onBackToRegister() {
    ref.read(ownerAuthControllerProvider.notifier).resetOnboarding();
    context.goNamed(RouteNames.register);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ownerAuthControllerProvider);

    ref.listen<OwnerAuthState>(ownerAuthControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Enter Verification Code',
                    style: AppTextStyles.headline.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We emailed a 6-digit code. Enter it below to verify your identity.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.grey600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildOtpFields(state),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    text: 'Verify & Continue',
                    isLoading: state.isLoading,
                    icon: Icons.verified_user_rounded,
                    onPressed: _onVerify,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppOutlineButton(
                          text: 'Back',
                          icon: Icons.arrow_back_rounded,
                          isLoading: state.isLoading,
                          onPressed: _onBackToRegister,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppOutlineButton(
                          text: _canResend
                              ? 'Resend Code'
                              : 'Resend (${_resendCountdown}s)',
                          icon: Icons.refresh_rounded,
                          isLoading: state.isLoading,
                          onPressed: _canResend ? _onResend : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpFields(OwnerAuthState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 44,
          child: TextFormField(
            controller: _otpControllers[index],
            focusNode: _otpFocusNodes[index],
            enabled: !state.isLoading,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: AppTextStyles.headline.copyWith(fontSize: 22),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.grey300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primaryDark, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.error, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.length == 1 && index < 5) {
                FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
              }
              if (value.isEmpty && index > 0) {
                FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
              }
              if (value.length == 1 && index == 5) {
                FocusScope.of(context).unfocus();
              }
            },
            onTap: () {
              _otpControllers[index].selection = TextSelection(
                baseOffset: 0,
                extentOffset: _otpControllers[index].value.text.length,
              );
            },
          ),
        );
      }),
    );
  }
}
