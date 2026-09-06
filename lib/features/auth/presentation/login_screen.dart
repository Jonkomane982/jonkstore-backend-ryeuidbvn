import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Using relative imports to bypass package resolution issues in the IDE
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/validators/app_validators.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/textfields/app_text_field.dart';
import '../../../shared/textfields/password_text_field.dart';
import '../../../shared/snackbars/custom_snack_bar.dart';
import '../controllers/auth_controller.dart';

/// The Login screen for JonkStore POS.
///
/// Allows users to authenticate using their email and password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(authControllerProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the authentication state
    final state = ref.watch(authControllerProvider);

    // Explicitly typed listener to help the IDE resolve 'next' properties
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isSuccess) {
        // Navigate to splash to re-evaluate the global app state
        context.goNamed(RouteNames.splash);
      }
      if (next.errorMessage != null) {
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
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
                    Icons.storefront_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'JonkStore POS',
                    style: AppTextStyles.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Welcome back, please login to continue',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  AppTextField(
                    label: 'Email Address',
                    hintText: 'Enter your email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => AppValidators.email(value),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  PasswordTextField(
                    controller: _passwordController,
                    validator: (value) => AppValidators.password(value),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          context.pushNamed(RouteNames.forgotPassword),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  PrimaryButton(
                    text: 'Login',
                    isLoading: state.isLoading,
                    onPressed: _onLogin,
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
