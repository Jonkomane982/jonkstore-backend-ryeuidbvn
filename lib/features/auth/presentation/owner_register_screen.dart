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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    final controller = ref.read(ownerAuthControllerProvider.notifier);
    
    await controller.startRegistration(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );
    
    final stateAfter = ref.read(ownerAuthControllerProvider);
    
    // Proceed to OTP stage even if registration "silently" failed due to existing account.
    // The OwnerService now handles password verification for existing accounts.
    if (stateAfter.isRegistrationStarted || stateAfter.errorMessage == null) {
      await controller.requestOtp();
      final stateAfterOtp = ref.read(ownerAuthControllerProvider);
      
      if (stateAfterOtp.isOtpSent && mounted) {
        // SECURITY: Generic message that doesn't reveal the specific email address
        CustomSnackBar.showSuccess(
          context,
          'A verification code has been sent to the owner email. Please enter it to continue.',
        );
        context.goNamed(RouteNames.verifyEmail);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ownerAuthControllerProvider);

    ref.listen<OwnerAuthState>(ownerAuthControllerProvider, (prev, next) {
      // SECURITY: Masking the 'already-in-use' error entirely in the UI.
      // The flow will proceed to OTP verification automatically.
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
                    'Owner Setup',
                    style: AppTextStyles.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Set up your owner identity. A 6-digit verification code will be sent to the registered email.',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  AppTextField(
                    label: 'Username',
                    hintText: 'Choose a unique username',
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
