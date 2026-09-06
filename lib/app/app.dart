import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/core_providers.dart';
import 'theme/app_theme.dart';

/// Main application widget for JonkStore POS.
/// 
/// Configures the global design system, themes, and navigation.
class JonkStoreApp extends ConsumerWidget {
  const JonkStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'JonkStore POS',
      debugShowCheckedModeBanner: false,
      
      // Theme Configuration
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Navigation Configuration
      routerConfig: router,
    );
  }
}
