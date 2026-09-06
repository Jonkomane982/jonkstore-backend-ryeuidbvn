import 'package:flutter/material.dart';

/// Centralized text styles for JonkStore POS.
///
/// Uses a cross-platform system font stack that avoids any remote CDN fetch.
abstract class AppTextStyles {
  static const String _fontFamily = 'Inter';

  static const List<String> _fontFamilyFallback = [
    'Inter',
    'Segoe UI',
    'Roboto',
    '-apple-system',
    'BlinkMacSystemFont',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static TextStyle get _baseStyle => const TextStyle(
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFamilyFallback,
    package: null,
  );

  /// Display Large - 57px, Bold
  static TextStyle get displayLarge => _baseStyle.copyWith(
    fontSize: 57,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.25,
  );

  /// Display Medium - 45px, Bold
  static TextStyle get displayMedium => _baseStyle.copyWith(
    fontSize: 45,
    fontWeight: FontWeight.bold,
    letterSpacing: 0,
  );

  /// Headline - 32px, Bold
  static TextStyle get headline => _baseStyle.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 0,
  );

  /// Title - 22px, SemiBold
  static TextStyle get title => _baseStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// Subtitle - 16px, SemiBold
  static TextStyle get subtitle => _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
  );

  /// Body Large - 16px, Regular
  static TextStyle get bodyLarge => _baseStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  /// Body - 14px, Regular
  static TextStyle get body => _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  /// Body Small - 12px, Regular
  static TextStyle get bodySmall => _baseStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  /// Caption - 11px, Regular
  static TextStyle get caption => _baseStyle.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  /// Button Text - 14px, Medium
  static TextStyle get button => _baseStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.25,
  );
}
