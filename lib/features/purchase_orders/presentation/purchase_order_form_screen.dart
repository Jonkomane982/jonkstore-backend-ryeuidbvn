import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/features/purchase_orders/controllers/purchase_controller.dart';
import 'package:jonkstore/features/products/controllers/product_controller.dart';
import 'package:jonkstore/features/suppliers/controllers/supplier_controller.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';

class PurchaseOrderFormScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const PurchaseOrderFormScreen({super.key, this.orderId});

  @override
  ConsumerState<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends ConsumerState<PurchaseOrderFormScreen> {
  final _runnerFeeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(productControllerProvider.notifier).loadProducts();
      await ref.read(supplierControllerProvider.notifier).loadSuppliers();
      
      if (widget.orderId != null) {
        await ref.read(purchaseControllerProvider.notifier).loadOrderForEditing(widget.orderId!);
        final currentState = ref.read(purchaseControllerProvider);
        _runnerFeeController.text = currentState.runnerFee.toStringAsFixed(0);
      } else {
        ref.read(purchaseControllerProvider.notifier).reset();
      }
    });

    _runnerFeeController.addListener(() {
      final fee = double.tryParse(_runnerFeeController.text) ?? 0;
      ref.read(purchaseControllerProvider.notifier).updateRunnerFee(fee);
    });
  }

  @override
  void dispose() {
    _runnerFeeController.dispose();
    super.dispose();
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => const _AddItemDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseControllerProvider);
    final supplierState = ref.watch(supplierControllerProvider);

    if (state.isLoading && widget.orderId != null && state.draftItems.isEmpty) {
      return const Scaffold(body: Center(child: AppLoadingIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderId == null ? 'New Purchase Order' : 'Edit Purchase Order'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Procurement Source'),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<Supplier>(
                    value: state.selectedSupplier,
                    decoration: const InputDecoration(
                      hintText: 'Select Supplier',
                      prefixIcon: Icon(Icons.business_center),
                    ),
                    items: supplierState.suppliers.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.name),
                    )).toList(),
                    onChanged: (val) => ref.read(purchaseControllerProvider.notifier).selectSupplier(val),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  _SectionHeader(
                    title: 'Inventory Items',
                    action: TextButton.icon(
                      onPressed: _showAddItemDialog,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add Product'),
                    ),
                  ),
                  
                  if (state.draftItems.isEmpty)
                    _EmptyItemsState(onAdd: _showAddItemDialog)
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.draftItems.length,
                      itemBuilder: (context, index) {
                        final item = state.draftItems[index];
                        return _PurchaseItemCard(item: item);
                      },
                    ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(title: 'Logistics Costs'),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppTextField(
                          label: 'Runner Fee',
                          controller: _runnerFeeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefixText: 'KES ',
                          hintText: '0.00',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<RunnerFeeAllocationMethod>(
                          value: state.allocationMethod,
                          decoration: const InputDecoration(label: Text('Allocation Method')),
                          items: const [
                            DropdownMenuItem(
                              value: RunnerFeeAllocationMethod.proportional,
                              child: Text('Proportional Cost'),
                            ),
                            DropdownMenuItem(
                              value: RunnerFeeAllocationMethod.equal,
                              child: Text('Equal Per Item'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(purchaseControllerProvider.notifier).updateAllocationMethod(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
          _buildSummarySection(state),
        ],
      ),
    );
  }

  Widget _buildSummarySection(PurchaseState state) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.lg)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _MiniSummary(label: 'Units', value: state.totalUnits.toStringAsFixed(0))),
                Expanded(child: _MiniSummary(label: 'Revenue', value: 'KES ${state.expectedRevenue.toStringAsFixed(0)}')),
                Expanded(child: _MiniSummary(
                  label: 'Exp. Profit', 
                  value: 'KES ${state.expectedProfit.toStringAsFixed(0)}',
                  valueColor: state.expectedProfit >= 0 ? AppColors.success : AppColors.error,
                )),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _SummaryRow(label: 'Buying Subtotal', value: state.subtotal),
            _SummaryRow(label: 'Runner Fee', value: state.runnerFee),
            _SummaryRow(
              label: 'Total Investment',
              value: state.totalInvestment,
              isTotal: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              text: widget.orderId == null ? 'Confirm Purchase' : 'Update Purchase',
              isLoading: state.isLoading,
              onPressed: (state.selectedSupplier != null && state.draftItems.isNotEmpty)
                  ? () async {
                      await ref.read(purchaseControllerProvider.notifier).createOrUpdateOrder();
                      if (mounted && ref.read(purchaseControllerProvider).isSuccess) {
                        CustomSnackBar.showSuccess(context, 'Purchase order saved');
                        context.pop();
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold, color: AppColors.grey700)),
        if (action != null) action!,
      ],
    );
  }
}

class _MiniSummary extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniSummary({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}

class _PurchaseItemCard extends ConsumerWidget {
  final DraftPurchaseItem item;

  const _PurchaseItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
        side: BorderSide(color: AppColors.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: const Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                      Text('SKU: ${item.product.sku ?? "No SKU"}', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.grey400, size: 20),
                  onPressed: () => ref.read(purchaseControllerProvider.notifier).removeFromDraft(item.product.id),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ItemInfo(label: 'Qty', value: item.quantity.toStringAsFixed(0)),
                _ItemInfo(label: 'Unit Cost', value: 'KES ${item.unitCost.toStringAsFixed(0)}'),
                _ItemInfo(
                  label: 'Landed Unit',
                  value: 'KES ${item.landedUnitCost.toStringAsFixed(1)}',
                  valueColor: AppColors.primary,
                ),
                _ItemInfo(label: 'Subtotal', value: 'KES ${item.total.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ItemInfo({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
        Text(value, style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.bold,
          color: valueColor,
          fontSize: 12,
        )),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;

  const _SummaryRow({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isTotal ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold) : AppTextStyles.body),
          Text(
            'KES ${value.toStringAsFixed(2)}',
            style: isTotal 
                ? AppTextStyles.title.copyWith(color: AppColors.primary, fontSize: 18)
                : AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyItemsState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: AppColors.grey200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.add_business_outlined, size: 48, color: AppColors.grey300),
          const SizedBox(height: AppSpacing.md),
          Text('No items added to this order', style: AppTextStyles.body.copyWith(color: AppColors.grey500)),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onAdd,
            child: const Text('Select Products'),
          ),
        ],
      ),
    );
  }
}

class _AddItemDialog extends ConsumerStatefulWidget {
  const _AddItemDialog();

  @override
  ConsumerState<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends ConsumerState<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productControllerProvider);

    return AlertDialog(
      title: const Text('Add Product'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: _selectedProduct,
                decoration: const InputDecoration(labelText: 'Product', prefixIcon: Icon(Icons.category)),
                items: productState.products.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name),
                )).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedProduct = val;
                    if (val?.costPrice != null) {
                      _costController.text = val!.costPrice.toStringAsFixed(0);
                    }
                  });
                },
                validator: (v) => v == null ? 'Selection required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Quantity',
                controller: _quantityController,
                keyboardType: TextInputType.number,
                validator: (v) => AppValidators.number(v, 'Quantity'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Unit Buying Price',
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => AppValidators.number(v, 'Price'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedProduct != null) {
              ref.read(purchaseControllerProvider.notifier).addToDraft(
                _selectedProduct!,
                double.parse(_quantityController.text),
                double.parse(_costController.text),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Add to Order'),
        ),
      ],
    );
  }
}
