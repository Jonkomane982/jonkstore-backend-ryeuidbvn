import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/core/domain/models/customer.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/features/customers/controllers/customer_controller.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isEditMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.customerId != null;
    if (_isEditMode) {
      _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    final repo = ref.read(customerRepositoryProvider);
    final result = await repo.findById(widget.customerId!);
    
    result.fold(
      (customer) {
        if (customer != null) {
          _nameController.text = customer.name;
          _emailController.text = customer.email ?? '';
          _phoneController.text = customer.phone ?? '';
          _addressController.text = customer.address ?? '';
        }
        setState(() => _isLoading = false);
      },
      (failure) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(context, failure.message);
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final business = await ref.read(currentBusinessProvider.future);
    if (business == null) {
      CustomSnackBar.showError(context, 'Business not found');
      return;
    }

    final customer = Customer(
      id: widget.customerId ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      businessId: business.id,
      createdAt: DateTime.now(), // Real logic keeps original
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    final repo = ref.read(customerRepositoryProvider);
    final result = _isEditMode ? await repo.update(customer) : await repo.create(customer);

    result.fold(
      (success) {
        CustomSnackBar.showSuccess(context, 'Customer saved');
        ref.read(customerControllerProvider.notifier).loadCustomers();
        context.pop();
      },
      (failure) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(context, failure.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Customer' : 'New Customer'),
      ),
      body: _isLoading && _isEditMode 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Full Name *',
                hintText: 'e.g. John Doe',
                controller: _nameController,
                validator: (v) => AppValidators.required(v, 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Phone Number',
                hintText: 'e.g. +254 700 000 000',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Email Address',
                hintText: 'john@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v != null && v.isNotEmpty ? AppValidators.email(v) : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Address',
                hintText: 'Physical address',
                controller: _addressController,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                text: _isEditMode ? 'Update Customer' : 'Create Customer',
                isLoading: _isLoading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
