import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/features/inventory/controllers/inventory_controller.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/core/domain/enums/inventory_transaction_type.dart';

class InventoryHistoryScreen extends ConsumerStatefulWidget {
  final String productId;

  const InventoryHistoryScreen({super.key, required this.productId});

  @override
  ConsumerState<InventoryHistoryScreen> createState() =>
      _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState
    extends ConsumerState<InventoryHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(inventoryControllerProvider.notifier)
          .loadHistory(widget.productId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movement History')),
      body: _buildContent(state),
    );
  }

  Widget _buildContent(InventoryState state) {
    if (state.isLoading) return const Center(child: AppLoadingIndicator());
    if (state.errorMessage != null)
      return Center(child: Text(state.errorMessage!));

    final history = state.transactionHistory;

    if (history.isEmpty) {
      return const EmptyState(
        title: 'No History',
        message: 'No stock movements recorded for this product yet.',
        icon: Icons.history_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: history.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final tx = history[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _buildTypeIcon(tx.type),
          title: Text(
            '${tx.quantityChange > 0 ? '+' : ''}${tx.quantityChange.toStringAsFixed(0)} items',
            style: AppTextStyles.subtitle.copyWith(
              color: tx.quantityChange > 0
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.notes ?? _getDefaultNote(tx.type)),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt),
                style: AppTextStyles.caption,
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Balance', style: AppTextStyles.caption),
              Text(
                tx.newQuantity.toStringAsFixed(0),
                style: AppTextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeIcon(InventoryTransactionType type) {
    IconData icon;
    Color color;

    switch (type) {
      case InventoryTransactionType.sale:
        icon = Icons.shopping_cart_checkout_rounded;
        color = AppColors.primary;
        break;
      case InventoryTransactionType.purchase:
        icon = Icons.add_business_rounded;
        color = AppColors.success;
        break;
      case InventoryTransactionType.adjustment:
        icon = Icons.edit_note_rounded;
        color = AppColors.warning;
        break;
      case InventoryTransactionType.damage:
        icon = Icons.broken_image_outlined;
        color = AppColors.error;
        break;
      case InventoryTransactionType.returnItem:
        icon = Icons.keyboard_return_rounded;
        color = AppColors.info;
        break;
      case InventoryTransactionType.supplierReturn:
        icon = Icons.reply_all_rounded;
        color = AppColors.warning;
        break;
      case InventoryTransactionType.stockCount:
        icon = Icons.countertops_rounded;
        color = AppColors.info;
        break;
      case InventoryTransactionType.transferIn:
        icon = Icons.move_to_inbox_rounded;
        color = AppColors.success;
        break;
      case InventoryTransactionType.transferOut:
        icon = Icons.outbox_rounded;
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getDefaultNote(InventoryTransactionType type) {
    switch (type) {
      case InventoryTransactionType.sale: return 'Sold to customer';
      case InventoryTransactionType.purchase: return 'Stock received';
      case InventoryTransactionType.adjustment: return 'Manual adjustment';
      case InventoryTransactionType.damage: return 'Damaged items';
      case InventoryTransactionType.returnItem: return 'Customer return';
      case InventoryTransactionType.supplierReturn: return 'Returned to supplier';
      case InventoryTransactionType.stockCount: return 'Stock count variance';
      case InventoryTransactionType.transferIn: return 'Stock transfer in';
      case InventoryTransactionType.transferOut: return 'Stock transfer out';
    }
  }
}
