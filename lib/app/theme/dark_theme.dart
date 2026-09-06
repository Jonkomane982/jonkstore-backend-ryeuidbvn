import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_radius.dart';

/// Dark theme configuration for JonkStore POS.
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.darkBackground,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    secondary: AppColors.secondary,
    onSecondary: AppColors.white,
    surface: AppColors.darkSurface,
    onSurface: AppColors.grey100,
    error: AppColors.error,
    onError: AppColors.white,
    outline: AppColors.grey700,
  ),
  textTheme: TextTheme(
    displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.grey50),
    displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.grey50),
    headlineMedium: AppTextStyles.headline.copyWith(color: AppColors.grey50),
    titleLarge: AppTextStyles.title.copyWith(color: AppColors.grey50),
    titleMedium: AppTextStyles.subtitle.copyWith(color: AppColors.grey50),
    bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey300),
    bodyMedium: AppTextStyles.body.copyWith(color: AppColors.grey300),
    bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500),
    labelSmall: AppTextStyles.caption.copyWith(color: AppColors.grey500),
    labelLarge: AppTextStyles.button.copyWith(color: AppColors.white),
  ),
  cardTheme: CardThemeData(
    color: AppColors.darkSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.borderRadiusLg,
      side: const BorderSide(color: AppColors.grey800),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkSurface,
    foregroundColor: AppColors.grey50,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: AppTextStyles.subtitle.copyWith(color: AppColors.grey50),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.grey900,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.grey700),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.grey700),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey600),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderRadiusMd,
      ),
      textStyle: AppTextStyles.button,
      elevation: 0,
    ),
  ),
);
