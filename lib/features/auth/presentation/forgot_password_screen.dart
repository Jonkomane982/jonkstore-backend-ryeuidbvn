import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/validators/app_validators.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/textfields/app_text_field.dart';
import '../../../shared/snackbars/custom_snack_bar.dart';
import '../controllers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      ref.read(authControllerProvider.notifier).resetPassword(
            _emailController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.isSuccess) {
        CustomSnackBar.showSuccess(
          context, 
          'Password reset link sent to your email.',
        );
        context.pop();
      }
      if (next.errorMessage != null) {
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Forgot your password?',
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter your email address and we will send you a link to reset your password.',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                AppTextField(
                  label: 'Email Address',
                  hintText: 'Enter your registered email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.email,
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                PrimaryButton(
                  text: 'Send Reset Link',
                  isLoading: state.isLoading,
                  onPressed: _onSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
