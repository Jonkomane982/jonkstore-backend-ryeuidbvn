import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/inventory.dart';
import 'package:jonkstore/core/domain/models/inventory_count.dart';
import 'package:jonkstore/core/domain/models/inventory_transaction.dart';
import 'package:jonkstore/core/domain/enums/inventory_transaction_type.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/features/inventory/controllers/inventory_controller.dart';
import 'package:jonkstore/features/products/controllers/product_controller.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';
import 'package:jonkstore/providers/auth_providers.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';

class InventoryCountScreen extends ConsumerStatefulWidget {
  const InventoryCountScreen({super.key});

  @override
  ConsumerState<InventoryCountScreen> createState() => _InventoryCountScreenState();
}

class _InventoryCountScreenState extends ConsumerState<InventoryCountScreen> {
  final Map<String, double> _countedQuantities = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());
  }

  void _loadData() async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business != null) {
      await ref.read(inventoryControllerProvider.notifier).loadInventory(business.id);
      await ref.read(productControllerProvider.notifier).loadProducts();
    }
  }

  Future<void> _submitCount() async {
    if (_countedQuantities.isEmpty) {
      CustomSnackBar.showWarning(context, 'No items counted.');
      return;
    }

    setState(() => _isSubmitting = true);

    final business = await ref.read(currentBusinessProvider.future);
    final user = ref.read(currentUserProvider);
    final inventoryState = ref.read(inventoryControllerProvider);

    if (business == null || user == null) {
      setState(() => _isSubmitting = false);
      CustomSnackBar.showError(context, 'Session session error.');
      return;
    }

    final countId = const Uuid().v4();
    final now = DateTime.now();

    final inventoryCount = InventoryCount(
      id: countId,
      branchId: business.id,
      countDate: now,
      status: 'CLOSED',
      notes: 'Physical stock count session',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
    );

    final List<InventoryTransaction> transactions = [];

    for (var entry in _countedQuantities.entries) {
      final productId = entry.key;
      final countedQty = entry.value;

      final inventory = inventoryState.inventoryItems.firstWhere((i) => i.productId == productId);
      final variance = countedQty - inventory.quantity;

      if (variance != 0) {
        transactions.add(InventoryTransaction(
          id: const Uuid().v4(),
          inventoryId: inventory.id,
          productId: productId,
          branchId: business.id,
          type: InventoryTransactionType.stockCount,
          quantityChange: variance,
          previousQuantity: inventory.quantity,
          newQuantity: countedQty,
          referenceId: countId,
          userId: user.id,
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
          syncStatus: SyncStatus.pending,
        ));
      }
    }

    final result = await ref.read(inventoryRepositoryProvider).createStockCount(inventoryCount, transactions);

    result.fold(
      (success) {
        CustomSnackBar.showSuccess(context, 'Stock count reconciled successfully.');
        context.pop();
      },
      (failure) {
        setState(() => _isSubmitting = false);
        CustomSnackBar.showError(context, failure.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryControllerProvider);
    final productState = ref.watch(productControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Count Session'),
      ),
      body: Column(
        children: [
          Expanded(
            child: inventoryState.isLoading
                ? const Center(child: AppLoadingIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: inventoryState.inventoryItems.length,
                    itemBuilder: (context, index) {
                      final item = inventoryState.inventoryItems[index];
                      final product = productState.products.firstWhere((p) => p.id == item.productId, orElse: () => null as dynamic);

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product.name, style: AppTextStyles.subtitle),
                                    Text('System: ${item.quantity.toStringAsFixed(0)}', style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: AppTextField(
                                  hintText: 'Actual',
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    final qty = double.tryParse(val);
                                    if (qty != null) {
                                      _countedQuantities[item.productId] = qty;
                                    } else {
                                      _countedQuantities.remove(item.productId);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: SafeArea(
              child: PrimaryButton(
                text: 'Submit & Reconcile',
                isLoading: _isSubmitting,
                onPressed: _submitCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
