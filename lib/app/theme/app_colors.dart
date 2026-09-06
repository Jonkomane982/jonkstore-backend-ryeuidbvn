import 'package:flutter/material.dart';

/// Centralized color palette for JonkStore POS.
///
/// Follows Material 3 color naming conventions where applicable.
abstract class AppColors {
  // Primary: Emerald Green
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFFD1FAE5);

  // Secondary: Royal Blue
  static const Color secondary = Color(0xFF3B82F6);
  static const Color secondaryDark = Color(0xFF2563EB);
  static const Color secondaryLight = Color(0xFFDBEAFE);

  // Success
  static const Color success = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);

  // Warning
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);

  // Error
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);

  // Info
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoDark = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFE0F2FE);

  // Neutral / Greyscale
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // Backgrounds
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color darkBackground = Color(0xFF0F172A);
  
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFF1E293B);
}
