import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized shadow constants for JonkStore POS.
/// 
/// Provides depth and elevation inspired by modern design systems like Stripe and Square.
abstract class AppShadows {
  /// Subtle shadow for cards and small elements.
  static List<BoxShadow> get small => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Standard shadow for main UI components.
  static List<BoxShadow> get medium => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// Deep shadow for overlays and floating elements.
  static List<BoxShadow> get large => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Extra deep shadow for modals and major dialogs.
  static List<BoxShadow> get xl => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.15),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];
      
  /// Dark mode shadows (more subtle, using dark surfaces)
  static List<BoxShadow> get darkMedium => [
        BoxShadow(
          color: AppColors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}
