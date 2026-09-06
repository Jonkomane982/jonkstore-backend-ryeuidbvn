import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/models/inventory.dart';
import 'package:jonkstore/core/domain/models/inventory_transaction.dart';
import 'package:jonkstore/core/domain/enums/inventory_transaction_type.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/features/inventory/controllers/inventory_controller.dart';
import 'package:jonkstore/providers/auth_providers.dart';

class InventoryAdjustmentScreen extends ConsumerStatefulWidget {
  final Product product;
  final Inventory inventory;

  const InventoryAdjustmentScreen({
    super.key,
    required this.product,
    required this.inventory,
  });

  @override
  ConsumerState<InventoryAdjustmentScreen> createState() => _InventoryAdjustmentScreenState();
}

class _InventoryAdjustmentScreenState extends ConsumerState<InventoryAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  InventoryTransactionType _selectedType = InventoryTransactionType.adjustment;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final changeValue = double.parse(_quantityController.text);
    // Adjustment can be negative (shrinkage/damage) or positive
    final newTotal = widget.inventory.quantity + changeValue;

    if (newTotal < 0) {
      CustomSnackBar.showError(context, 'Inventory cannot be less than zero');
      return;
    }

    final transaction = InventoryTransaction(
      id: const Uuid().v4(),
      inventoryId: widget.inventory.id,
      productId: widget.product.id,
      branchId: widget.inventory.branchId,
      quantityChanged: changeValue,
      resultingQuantity: newTotal,
      type: _selectedType,
      notes: _notesController.text.trim(),
      userId: user.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    await ref.read(inventoryControllerProvider.notifier).recordMovement(transaction);
    
    if (mounted) {
      CustomSnackBar.showSuccess(context, 'Stock level updated');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Stock'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.product.name, style: AppTextStyles.title),
              Text('Current Stock: ${widget.inventory.quantity.toStringAsFixed(0)}', style: AppTextStyles.bodyLarge),
              const SizedBox(height: AppSpacing.xl),
              
              Text('Adjustment Reason', style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<InventoryTransactionType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                items: [
                  InventoryTransactionType.adjustment,
                  InventoryTransactionType.damage,
                  InventoryTransactionType.returnItem,
                  InventoryTransactionType.purchase,
                ].map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                )).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: AppSpacing.md),
              
              AppTextField(
                label: 'Quantity Change (Use - for reduction)',
                hintText: 'e.g. 10 or -5',
                controller: _quantityController,
                keyboardType: TextInputType.number,
                validator: (v) => AppValidators.number(v, 'Quantity'),
              ),
              const SizedBox(height: AppSpacing.md),
              
              AppTextField(
                label: 'Notes',
                hintText: 'Reason for adjustment...',
                controller: _notesController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              PrimaryButton(
                text: 'Update Stock Level',
                onPressed: _saveAdjustment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
