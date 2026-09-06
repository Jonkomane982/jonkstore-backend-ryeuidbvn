import 'package:flutter/material.dart';

/// Centralized border radius constants for JonkStore POS.
abstract class AppRadius {
  /// 4.0
  static const double sm = 4.0;
  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(sm));

  /// 8.0
  static const double md = 8.0;
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(md));

  /// 12.0
  static const double lg = 12.0;
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(lg));

  /// 16.0
  static const double xl = 16.0;
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(xl));

  /// 24.0
  static const double xxl = 24.0;
  static const BorderRadius borderRadiusXxl = BorderRadius.all(Radius.circular(xxl));

  /// 999.0
  static const double pill = 999.0;
  static const BorderRadius borderRadiusPill = BorderRadius.all(Radius.circular(pill));
}
