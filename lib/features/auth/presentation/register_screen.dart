import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/validators/app_validators.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/textfields/app_text_field.dart';
import '../../../shared/textfields/password_text_field.dart';
import '../../../shared/snackbars/custom_snack_bar.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState!.validate()) {
      ref.read(authControllerProvider.notifier).register(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            _nameController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next.isSuccess) {
        context.goNamed(RouteNames.verifyEmail);
      }
      if (next.errorMessage != null) {
        CustomSnackBar.showError(context, next.errorMessage!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join JonkStore POS',
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Create an owner account to start managing your business.',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                AppTextField(
                  label: 'Full Name',
                  hintText: 'Enter your name',
                  controller: _nameController,
                  validator: (value) => AppValidators.required(value, 'Name'),
                ),
                const SizedBox(height: AppSpacing.md),
                
                AppTextField(
                  label: 'Email Address',
                  hintText: 'Enter your email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.email,
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
                  hintText: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                PrimaryButton(
                  text: 'Create Account',
                  isLoading: state.isLoading,
                  onPressed: _onRegister,
                ),
                const SizedBox(height: AppSpacing.lg),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?', style: AppTextStyles.body),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
