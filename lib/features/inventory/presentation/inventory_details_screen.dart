import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/inventory.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/inventory/controllers/inventory_controller.dart';
import 'package:jonkstore/features/products/controllers/product_controller.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/buttons/outline_button.dart';
import 'package:go_router/go_router.dart';

class InventoryDetailsScreen extends ConsumerStatefulWidget {
  final String productId;
  final String branchId;

  const InventoryDetailsScreen({
    super.key,
    required this.productId,
    required this.branchId,
  });

  @override
  ConsumerState<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends ConsumerState<InventoryDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(inventoryControllerProvider.notifier).loadHistory(widget.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryControllerProvider);
    final productState = ref.watch(productControllerProvider);

    // Find the specific inventory and product locally
    final inventory = inventoryState.inventoryItems.firstWhere(
      (element) => element.productId == widget.productId && element.branchId == widget.branchId,
      orElse: () => null as dynamic,
    );

    final product = productState.products.firstWhere(
      (element) => element.id == widget.productId,
      orElse: () => null as dynamic,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.pushNamed(
              RouteNames.inventoryHistory,
              pathParameters: {'id': product.id},
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStockHeader(inventory, product),
            const SizedBox(height: AppSpacing.xl),
            _buildDetailsCard(inventory, product),
            const SizedBox(height: AppSpacing.xl),
            _buildActionButtons(context, inventory, product),
            const SizedBox(height: AppSpacing.xl),
            Text('Recent Movements', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.md),
            _buildRecentMovements(inventoryState),
          ],
        ),
      ),
    );
  }

  Widget _buildStockHeader(Inventory inventory, Product product) {
    final isLowStock = inventory.quantity <= (inventory.lowStockThreshold ?? 0);
    return Center(
      child: Column(
        children: [
          Text(
            inventory.quantity.toStringAsFixed(0),
            style: AppTextStyles.displayLarge.copyWith(
              color: isLowStock ? AppColors.error : AppColors.primary,
            ),
          ),
          Text(
            'Units in Stock',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey500),
          ),
          if (isLowStock)
            Container(
              margin: const EdgeInsets.top(AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'LOW STOCK ALERT',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(Inventory inventory, Product product) {
    final cost = product.costPrice ?? 0;
    final valuation = inventory.quantity * cost;
    return PrimaryCard(
      child: Column(
        children: [
          _buildInfoRow('SKU', product.sku ?? 'N/A'),
          _buildInfoRow('Barcode', product.barcode ?? 'N/A'),
          _buildInfoRow('Category ID', product.categoryId),
          const Divider(height: 32),
          _buildInfoRow('Unit Cost', 'KES ${cost.toStringAsFixed(2)}'),
          _buildInfoRow('Inventory Value', 'KES ${valuation.toStringAsFixed(2)}', isBold: true),
          const Divider(height: 32),
          _buildInfoRow('Threshold', '${inventory.lowStockThreshold ?? 0} units'),
          _buildInfoRow('Last Count', inventory.lastCountDate != null ? DateFormat('dd MMM yyyy').format(inventory.lastCountDate!) : 'Never'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body.copyWith(color: AppColors.grey500)),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Inventory inventory, Product product) {
    return Row(
      children: [
        Expanded(
          child: AppOutlineButton(
            text: 'Adjust Stock',
            onPressed: () => context.pushNamed(
              RouteNames.inventoryAdjustment,
              extra: {'product': product, 'inventory': inventory},
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: PrimaryButton(
            text: 'Stock Count',
            onPressed: () {
              // Navigate to stock count session for this product
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMovements(InventoryState state) {
    if (state.isLoading) return const Center(child: AppLoadingIndicator());
    final history = state.transactionHistory.take(5).toList();
    if (history.isEmpty) return const Text('No recent movements recorded.');

    return Column(
      children: history.map((tx) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            tx.quantityChange > 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: tx.quantityChange > 0 ? AppColors.success : AppColors.error,
          ),
          title: Text('${tx.quantityChange > 0 ? '+' : ''}${tx.quantityChange} units'),
          subtitle: Text(DateFormat('dd MMM, hh:mm a').format(tx.transactionDate)),
          trailing: Text(
            tx.type.name.toUpperCase(),
            style: AppTextStyles.caption,
          ),
        );
      }).toList(),
    );
  }
}
