import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/inventory/controllers/inventory_controller.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/textfields/search_text_field.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/core/domain/models/inventory.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business != null) {
      // For now using businessId as branchId as we haven't built multiple branches yet
      ref.read(inventoryControllerProvider.notifier).loadInventory(business.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SearchTextField(
              controller: _searchController,
              hintText: 'Search inventory...',
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _buildContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(InventoryState state) {
    if (state.isLoading) return const Center(child: AppLoadingIndicator());
    if (state.errorMessage != null) return Center(child: Text(state.errorMessage!));

    final items = state.inventoryItems.where((item) {
      // This is simplified; in production we'd join with product table in DAO
      return true; 
    }).toList();

    if (items.isEmpty) {
      return const EmptyState(
        title: 'No Inventory Records',
        message: 'Products with "Track Inventory" enabled will appear here.',
        icon: Icons.warehouse_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final inventory = items[index];
        return _InventoryItemTile(inventory: inventory);
      },
    );
  }
}

class _InventoryItemTile extends ConsumerWidget {
  final Inventory inventory;
  const _InventoryItemTile({required this.inventory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch product details for this inventory item
    final productAsync = ref.watch(productRepositoryProvider).findById(inventory.productId);

    return FutureBuilder(
      future: productAsync,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final productResult = snapshot.data!;
        return productResult.fold(
          (product) {
            if (product == null) return const SizedBox.shrink();
            final isLowStock = inventory.quantity <= inventory.lowStockThreshold;

            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                onTap: () => context.pushNamed(
                  '${RouteNames.inventory}-history',
                  pathParameters: {'id': product.id},
                ),
                title: Text(product.name, style: AppTextStyles.subtitle.copyWith(fontSize: 16)),
                subtitle: Text('SKU: ${product.sku ?? 'N/A'}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${inventory.quantity.toStringAsFixed(0)} in stock',
                      style: AppTextStyles.subtitle.copyWith(
                        color: isLowStock ? AppColors.error : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isLowStock)
                      Text(
                        'Low Stock Alert',
                        style: AppTextStyles.caption.copyWith(color: AppColors.error),
                      ),
                  ],
                ),
              ),
            );
          },
          (failure) => const SizedBox.shrink(),
        );
      },
    );
  }
}
