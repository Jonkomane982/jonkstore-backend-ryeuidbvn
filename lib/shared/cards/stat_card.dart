import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import 'primary_card.dart';

/// A card for displaying statistics, such as total sales, orders, or customers.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? trend;
  final bool isPositiveTrend;
  final IconData? icon;
  final Color? iconColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.trend,
    this.isPositiveTrend = true,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.grey500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppColors.grey400,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.headline.copyWith(
              fontSize: 24,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(
                  isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: isPositiveTrend ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  trend!,
                  style: AppTextStyles.caption.copyWith(
                    color: isPositiveTrend ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
