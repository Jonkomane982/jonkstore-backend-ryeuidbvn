import 'package:flutter/material.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_shadows.dart';

/// A standard card component with consistent padding and styling.
class PrimaryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? color;
  final BorderSide? borderSide;

  const PrimaryCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.color,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardTheme = Theme.of(context).cardTheme;

    // Correctly resolve the border side without type conflicts
    BorderSide effectiveBorderSide = BorderSide.none;
    if (borderSide != null) {
      effectiveBorderSide = borderSide!;
    } else if (cardTheme.shape is RoundedRectangleBorder) {
      effectiveBorderSide = (cardTheme.shape as RoundedRectangleBorder).side;
    }

    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? cardTheme.color,
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.fromBorderSide(effectiveBorderSide),
        boxShadow: isDark ? AppShadows.darkMedium : AppShadows.small,
      ),
      child: child,
    );
  }
}
