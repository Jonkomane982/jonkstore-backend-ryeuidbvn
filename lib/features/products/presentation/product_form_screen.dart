import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/models/category.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/features/products/controllers/product_controller.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategoryId;
  bool _trackInventory = true;
  bool _isActive = true;
  bool _isEditMode = false;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.productId != null;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load categories for dropdown
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final categoryResult = await categoryRepo.findAll();
    categoryResult.fold(
      (categories) => setState(() => _categories = categories),
      (failure) =>
          CustomSnackBar.showError(context, 'Failed to load categories'),
    );

    if (_isEditMode) {
      final productRepo = ref.read(productRepositoryProvider);
      final productResult = await productRepo.findById(widget.productId!);
      productResult.fold((product) {
        if (product != null) {
          _nameController.text = product.name;
          _skuController.text = product.sku ?? '';
          _barcodeController.text = product.barcode ?? '';
          _priceController.text = product.price.toString();
          _costPriceController.text = product.costPrice.toString();
          _descriptionController.text = product.description ?? '';
          setState(() {
            _selectedCategoryId = product.categoryId;
            _trackInventory = product.trackInventory;
            _isActive = product.isActive;
          });
        }
      }, (failure) => CustomSnackBar.showError(context, failure.message));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      CustomSnackBar.showError(context, 'Please select a category');
      return;
    }

    final businessResult = await ref.read(currentBusinessProvider.future);
    if (businessResult == null) {
      CustomSnackBar.showError(context, 'Business configuration not found');
      return;
    }

    final product = Product(
      id: _isEditMode ? widget.productId! : const Uuid().v4(),
      businessId: businessResult.id,
      unitId: 'default',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      sellingPrice: double.tryParse(_priceController.text) ?? 0.0,
      buyingPrice: double.tryParse(_costPriceController.text) ?? 0.0,
      categoryId: _selectedCategoryId,
      trackInventory: _trackInventory,
      isActive: _isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    final repository = ref.read(productRepositoryProvider);
    final result = _isEditMode
        ? await repository.update(product)
        : await repository.create(product);

    result.fold((success) {
      CustomSnackBar.showSuccess(context, 'Product saved successfully');
      ref.read(productControllerProvider.notifier).loadProducts();
      context.pop();
    }, (failure) => CustomSnackBar.showError(context, failure.message));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Product' : 'New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Product Name *',
                hintText: 'e.g. Milk 1L',
                controller: _nameController,
                validator: (v) => AppValidators.required(v, 'Product Name'),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Price (Selling) *',
                      hintText: '0.00',
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      validator: (v) => AppValidators.number(v, 'Price'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Cost Price',
                      hintText: '0.00',
                      controller: _costPriceController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Category Dropdown
              Text(
                'Category *',
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  hintText: 'Select Category',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'SKU',
                      hintText: 'Stock Keeping Unit',
                      controller: _skuController,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Barcode',
                      hintText: 'UPC/EAN',
                      controller: _barcodeController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                label: 'Description',
                hintText: 'Product details...',
                controller: _descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),

              SwitchListTile(
                title: const Text('Track Inventory'),
                subtitle: const Text(
                  'Enable stock level management for this item',
                ),
                value: _trackInventory,
                onChanged: (val) => setState(() => _trackInventory = val),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Active'),
                subtitle: const Text('Visible in POS and available for sale'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                text: _isEditMode ? 'Update Product' : 'Create Product',
                onPressed: _saveProduct,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
