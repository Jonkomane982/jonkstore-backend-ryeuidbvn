import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_radius.dart';

/// Light theme configuration for JonkStore POS.
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.lightBackground,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.white,
    secondary: AppColors.secondary,
    onSecondary: AppColors.white,
    surface: AppColors.lightSurface,
    onSurface: AppColors.grey900,
    error: AppColors.error,
    onError: AppColors.white,
    outline: AppColors.grey300,
  ),
  textTheme: TextTheme(
    displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.grey900),
    displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.grey900),
    headlineMedium: AppTextStyles.headline.copyWith(color: AppColors.grey900),
    titleLarge: AppTextStyles.title.copyWith(color: AppColors.grey900),
    titleMedium: AppTextStyles.subtitle.copyWith(color: AppColors.grey900),
    bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey700),
    bodyMedium: AppTextStyles.body.copyWith(color: AppColors.grey700),
    bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500),
    labelSmall: AppTextStyles.caption.copyWith(color: AppColors.grey500),
    labelLarge: AppTextStyles.button.copyWith(color: AppColors.white),
  ),
  cardTheme: CardThemeData(
    color: AppColors.lightSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.borderRadiusLg,
      side: const BorderSide(color: AppColors.grey200),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.lightSurface,
    foregroundColor: AppColors.grey900,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: AppTextStyles.subtitle.copyWith(color: AppColors.grey900),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.grey300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.grey300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.error),
    ),
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
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
