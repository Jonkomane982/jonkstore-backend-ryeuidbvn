import 'package:flutter/material.dart';
import 'light_theme.dart';
import 'dark_theme.dart';

/// Entry point for JonkStore POS theme management.
class AppTheme {
  AppTheme._();

  /// Returns the light theme configuration.
  static ThemeData get light => lightTheme;

  /// Returns the dark theme configuration.
  static ThemeData get dark => darkTheme;
}
