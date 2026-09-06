import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/inventory/controllers/inventory_controller.dart';
import 'package:jonkstore/shared/cards/stat_card.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends ConsumerState<InventoryDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business != null) {
      ref.read(inventoryControllerProvider.notifier).loadInventory(business.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStats(state),
              const SizedBox(height: AppSpacing.xl),
              Text('Inventory Actions', style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.md),
              _buildActions(context),
              const SizedBox(height: AppSpacing.xl),
              Text('Alerts', style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.md),
              _buildAlerts(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(InventoryState state) {
    final items = state.inventoryItems;
    final lowStockCount = items.where((i) => i.quantity <= i.lowStockThreshold).length;
    final outOfStockCount = items.where((i) => i.quantity <= 0).length;
    final totalItems = items.length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          title: 'Total Tracked Items',
          value: '$totalItems',
          icon: Icons.inventory_2_outlined,
        ),
        StatCard(
          title: 'Low Stock',
          value: '$lowStockCount',
          icon: Icons.warning_amber_rounded,
          iconColor: lowStockCount > 0 ? AppColors.error : null,
        ),
        StatCard(
          title: 'Out of Stock',
          value: '$outOfStockCount',
          icon: Icons.error_outline_rounded,
          iconColor: outOfStockCount > 0 ? AppColors.error : null,
        ),
        const StatCard(
          title: 'Inventory Value',
          value: 'KES 0.00', // To be calculated via InventoryCalculationService
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.5,
      children: [
        _ActionTile(
          title: 'Full Inventory',
          icon: Icons.list_alt_rounded,
          onTap: () => context.pushNamed(RouteNames.inventory),
        ),
        _ActionTile(
          title: 'Stock Count',
          icon: Icons.inventory_rounded,
          onTap: () {}, // To be implemented
        ),
        _ActionTile(
          title: 'Stock Transfer',
          icon: Icons.move_up_rounded,
          onTap: () {}, // To be implemented
        ),
        _ActionTile(
          title: 'Audit Log',
          icon: Icons.history_rounded,
          onTap: () {}, // Navigate to global history
        ),
      ],
    );
  }

  Widget _buildAlerts(InventoryState state) {
    final lowStock = state.inventoryItems.where((i) => i.quantity <= i.lowStockThreshold).toList();

    if (lowStock.isEmpty) {
      return const PrimaryCard(
        child: Center(
          child: Text('No active stock alerts.'),
        ),
      );
    }

    return Column(
      children: lowStock.map((item) => Card(
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          title: Text('Product ID: ${item.productId.substring(0, 8)}'),
          subtitle: Text('Current Stock: ${item.quantity.toStringAsFixed(0)}'),
          trailing: TextButton(
            onPressed: () => context.pushNamed(
              RouteNames.inventoryAdjustment,
              extra: {'productId': item.productId, 'inventory': item}, // Placeholder extra
            ),
            child: const Text('ADJUST'),
          ),
        ),
      )).toList(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionTile({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: PrimaryCard(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
