import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/buttons/outline_button.dart';
import '../../../shared/snackbars/custom_snack_bar.dart';
import '../../../providers/auth_providers.dart';
import '../../../core/auth/session_manager.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _timer;
  bool _canResendEmail = true;

  @override
  void initState() {
    super.initState();
    // Periodically check if email is verified
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    await ref.read(sessionManagerProvider.notifier).refreshSession();
    final isVerified = ref.read(sessionManagerProvider).isEmailVerified;
    
    if (isVerified) {
      _timer?.cancel();
      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Email verified successfully!');
        context.goNamed(RouteNames.splash);
      }
    }
  }

  Future<void> _resendEmail() async {
    if (!_canResendEmail) return;

    final result = await ref.read(authRepositoryProvider).sendEmailVerification();
    
    result.fold(
      (_) {
        setState(() => _canResendEmail = false);
        CustomSnackBar.showSuccess(context, 'Verification email resent.');
        Future.delayed(const Duration(seconds: 60), () {
          if (mounted) setState(() => _canResendEmail = true);
        });
      },
      (failure) => CustomSnackBar.showError(context, failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionManagerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        actions: [
          IconButton(
            onPressed: () => ref.read(sessionManagerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Verify your email',
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'A verification link has been sent to ${user?.email ?? 'your email'}. Please check your inbox and click the link to activate your account.',
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              PrimaryButton(
                text: 'Resend Email',
                onPressed: _canResendEmail ? _resendEmail : null,
              ),
              const SizedBox(height: AppSpacing.md),
              
              AppOutlineButton(
                text: 'Cancel',
                onPressed: () => ref.read(sessionManagerProvider.notifier).logout(),
              ),
              if (!_canResendEmail) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Wait 60 seconds before resending',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
