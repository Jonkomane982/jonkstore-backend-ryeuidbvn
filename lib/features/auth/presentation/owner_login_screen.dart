import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/textfields/password_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import '../controllers/owner_auth_controller.dart';

class OwnerLoginScreen extends ConsumerStatefulWidget {
  const OwnerLoginScreen({super.key});

  @override
  ConsumerState<OwnerLoginScreen> createState() => _OwnerLoginScreenState();
}

class _OwnerLoginScreenState extends ConsumerState<OwnerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final controller = ref.read(ownerAuthControllerProvider.notifier);
    
    // Verifies password then triggers OTP flow
    await controller.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    
    final state = ref.read(ownerAuthControllerProvider);
    if (state.isOtpSent && mounted) {
      CustomSnackBar.showSuccess(context, 'Verification code sent to owner email.');
      context.goNamed(RouteNames.verifyEmail);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    await ref.read(ownerAuthControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ownerAuthControllerProvider);

    ref.listen<OwnerAuthState>(ownerAuthControllerProvider, (prev, next) {
      if (next.isLoginSuccess && next.profile != null) {
        if (!mounted) return;
        context.goNamed(RouteNames.dashboard);
      }
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        if (!mounted) return;
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront_rounded, size: 72, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'JonkStore POS',
                      style: AppTextStyles.headline.copyWith(color: AppColors.grey900),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Owner Access',
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    
                    AppTextField(
                      label: 'Username',
                      hintText: 'Enter owner username',
                      controller: _usernameController,
                      validator: (v) => AppValidators.required(v, 'Username'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordTextField(
                      label: 'Password',
                      controller: _passwordController,
                      validator: (v) => AppValidators.required(v, 'Password'),
                      onFieldSubmitted: (_) => _onSubmit(),
                    ),
                    
                    // ACCOUNT RECOVERY: Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ref.read(ownerAuthControllerProvider.notifier).forgotPassword();
                          CustomSnackBar.showSuccess(context, 'If authorized, a reset link has been sent.');
                        },
                        child: Text(
                          'Forgot Password?',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      text: 'Sign In',
                      isLoading: state.isLoading,
                      onPressed: _onSubmit,
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    _buildDivider(),
                    const SizedBox(height: AppSpacing.xl),
                    
                    _GoogleSignInButton(
                      isLoading: state.isLoading,
                      onPressed: _handleGoogleSignIn,
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    TextButton(
                      onPressed: () => context.pushNamed(RouteNames.register),
                      child: RichText(
                        text: TextSpan(
                          text: 'New to JonkStore? ',
                          style: AppTextStyles.body.copyWith(color: AppColors.grey600),
                          children: [
                            TextSpan(
                              text: 'Create Owner Account',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'OR',
            style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _GoogleSignInButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: AppColors.grey300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_\"G\"_Logo.svg',
            height: 20,
            errorBuilder: (context, _, __) => const Icon(Icons.g_mobiledata, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Continue with Google',
            style: AppTextStyles.button.copyWith(color: AppColors.grey800),
          ),
        ],
      ),
    );
  }
}
