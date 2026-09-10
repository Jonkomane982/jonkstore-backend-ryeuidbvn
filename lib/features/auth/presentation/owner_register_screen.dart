import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/textfields/password_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import '../controllers/owner_auth_controller.dart';

class OwnerRegisterScreen extends ConsumerStatefulWidget {
  const OwnerRegisterScreen({super.key});

  @override
  ConsumerState<OwnerRegisterScreen> createState() =>
      _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends ConsumerState<OwnerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final controller = ref.read(ownerAuthControllerProvider.notifier);
    
    await controller.startRegistration(
      email: email,
      username: username,
      password: password,
    );
    
    final stateAfter = ref.read(ownerAuthControllerProvider);
    
    if (stateAfter.isRegistrationStarted || stateAfter.errorMessage == null) {
      await controller.requestOtp(email);
      final stateAfterOtp = ref.read(ownerAuthControllerProvider);
      
      if (stateAfterOtp.isOtpSent && mounted) {
        CustomSnackBar.showSuccess(
          context,
          'A verification code has been sent to your email.',
        );
        context.goNamed(RouteNames.verifyEmail);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ownerAuthControllerProvider);

    ref.listen<OwnerAuthState>(ownerAuthControllerProvider, (prev, next) {
      if (next.errorMessage != null && 
          next.errorMessage!.isNotEmpty && 
          !next.errorMessage!.toLowerCase().contains('already-in-use')) {
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
                    Icons.admin_panel_settings_rounded,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Create Account',
                    style: AppTextStyles.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Join the JonkStore POS system. A verification code will be sent to your email.',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  AppTextField(
                    label: 'Email Address',
                    hintText: 'Enter your email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: AppValidators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: 'Username',
                    hintText: 'Choose a display name',
                    controller: _usernameController,
                    validator: (v) => AppValidators.required(v, 'Username'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  PasswordTextField(
                    label: 'Password',
                    controller: _passwordController,
                    validator: AppValidators.password,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  PasswordTextField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  PrimaryButton(
                    text: 'Continue',
                    isLoading: state.isLoading,
                    onPressed: _onRegister,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.body,
                      ),
                      TextButton(
                        onPressed: () {
                          context.goNamed(RouteNames.login);
                        },
                        child: Text(
                          'Sign In',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.green,
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
