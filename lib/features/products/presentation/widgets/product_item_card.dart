import 'package:flutter/material.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';

class ProductItemCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ProductItemCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimaryCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          ),
          title: Text(
            product.name,
            style: AppTextStyles.subtitle.copyWith(fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SKU: ${product.sku ?? 'N/A'}',
                style: AppTextStyles.bodySmall,
              ),
              if (product.barcode != null)
                Text(
                  'Barcode: ${product.barcode}',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'KES ${product.price.toStringAsFixed(2)}',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!product.isActive)
                Text(
                  'Inactive',
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
