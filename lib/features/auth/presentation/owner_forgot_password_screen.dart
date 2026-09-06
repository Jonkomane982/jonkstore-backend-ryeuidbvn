import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/config/app_owner.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import '../controllers/owner_auth_controller.dart';

class OwnerForgotPasswordScreen extends ConsumerStatefulWidget {
  const OwnerForgotPasswordScreen({super.key});

  @override
  ConsumerState<OwnerForgotPasswordScreen> createState() =>
      _OwnerForgotPasswordScreenState();
}

class _OwnerForgotPasswordScreenState
    extends ConsumerState<OwnerForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: AppOwner.ownerEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSendResetLink() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(ownerAuthControllerProvider.notifier)
          .forgotPassword(email: _emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ownerAuthControllerProvider);

    ref.listen<OwnerAuthState>(ownerAuthControllerProvider, (previous, next) {
      if (next.isPasswordResetSent) {
        CustomSnackBar.showSuccess(
          context,
          'Password reset link sent! Check your email inbox.',
        );
      }
      if (next.errorMessage != null && !next.isPasswordResetSent) {
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    if (state.isPasswordResetSent) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reset Password'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.goNamed(RouteNames.login);
            },
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    size: 100,
                    color: Colors.green,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Check Your Email',
                    style: AppTextStyles.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'We have sent a password reset link to:\n${_emailController.text.trim()}',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    "Didn't receive the email? Check your spam folder or try again.",
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    text: 'Resend Link',
                    onPressed: _onSendResetLink,
                    isLoading: state.isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    text: 'Back to Login',
                    onPressed: () {
                      context.goNamed(RouteNames.login);
                    },
                    backgroundColor: AppColors.grey200,
                    foregroundColor: AppColors.grey800,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_reset_rounded,
                    size: 100,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Forgot Password?',
                    style: AppTextStyles.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Enter your registered email and we will send you a link to reset your password.',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    label: 'Registered Email',
                    hintText: 'Enter your owner email address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: AppValidators.email,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  PrimaryButton(
                    text: 'Send Reset Link',
                    isLoading: state.isLoading,
                    onPressed: _onSendResetLink,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Remember your password? ',
                        style: AppTextStyles.body,
                      ),
                      TextButton(
                        onPressed: () {
                          context.goNamed(RouteNames.login);
                        },
                        child: Text(
                          'Sign In',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
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
}
