import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/providers/owner_providers.dart';
import '../controllers/business_setup_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Production delay for branding
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 1. Check if an Owner Profile exists locally
    final ownerProfile = await ref.read(ownerRepositoryProvider).getProfile();

    ownerProfile.fold(
      (profile) async {
        if (profile == null) {
          // No owner account found - Redirect to login (registration is restricted)
          context.goNamed(RouteNames.login);
          return;
        }

        // 2. Check if the user is currently authenticated with Firebase
        final ownerService = ref.read(ownerServiceProvider);
        final verificationResult = await ownerService.checkVerificationStatus();

        verificationResult.fold(
          (isVerified) async {
            if (!isVerified) {
              context.goNamed(RouteNames.verifyEmail);
              return;
            }

            // 3. Check if Business is setup
            final isBusinessConfigured = await ref.read(
              isBusinessConfiguredProvider.future,
            );
            if (isBusinessConfigured) {
              context.goNamed(RouteNames.dashboard);
            } else {
              context.goNamed(RouteNames.businessSetup);
            }
          },
          (failure) {
            // Authentication expired or not logged in
            context.goNamed(RouteNames.login);
          },
        );
      },
      (failure) {
        // SQLite failure - critical error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Critical Error: ${failure.message}')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, size: 80, color: Colors.white),
            SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
