import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// A standard loading indicator for JonkStore POS.
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const AppLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? AppColors.primary,
          ),
        ),
      ),
    );
  }

  /// Full screen loading overlay.
  static Widget fullScreen() {
    return const Scaffold(
      body: Center(
        child: AppLoadingIndicator(size: 40),
      ),
    );
  }
}
