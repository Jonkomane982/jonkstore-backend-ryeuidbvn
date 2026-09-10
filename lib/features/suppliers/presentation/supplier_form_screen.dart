import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_radius.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/auth/app_permission.dart';
import 'package:jonkstore/core/auth/permission_provider.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/features/suppliers/controllers/supplier_list_controller.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/shared/buttons/outline_button.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/guards/permission_guard.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final String? supplierId;

  const SupplierFormScreen({super.key, this.supplierId});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _websiteController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isEditMode = false;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _isActive = true;
  Supplier? _existing;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.supplierId != null;
    if (_isEditMode) {
      _loadSupplier();
    }
  }

  Future<void> _loadSupplier() async {
    setState(() => _isLoading = true);
    final repo = ref.read(supplierRepositoryProvider);
    final result = await repo.findById(widget.supplierId!);
    if (!mounted) return;
    result.fold(
      (supplier) {
        if (supplier != null) {
          _existing = supplier;
          _nameController.text = supplier.name;
          _codeController.text = supplier.code;
          _taxIdController.text = supplier.taxId ?? '';
          _websiteController.text = supplier.website ?? '';
          _contactNameController.text = supplier.contactName ?? '';
          _emailController.text = supplier.email ?? '';
          _phoneController.text = supplier.phone ?? '';
          _addressController.text = supplier.address ?? '';
          _cityController.text = supplier.city ?? '';
          _stateController.text = supplier.state ?? '';
          _countryController.text = supplier.country ?? '';
          _postalCodeController.text = supplier.postalCode ?? '';
          _paymentTermsController.text = supplier.paymentTerms ?? '';
          _creditLimitController.text = supplier.creditLimit == 0
              ? ''
              : supplier.creditLimit.toString();
          _notesController.text = supplier.notes ?? '';
          _isActive = supplier.isActive;
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
    _codeController.dispose();
    _taxIdController.dispose();
    _websiteController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _paymentTermsController.dispose();
    _creditLimitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final hasPermission = ref.read(
      hasPermissionProvider(AppPermission.manageSuppliers),
    );
    if (!hasPermission) {
      CustomSnackBar.showError(
        context,
        'You do not have permission to manage suppliers.',
      );
      return;
    }

    setState(() => _isSaving = true);

    final business = await ref.read(currentBusinessProvider.future);
    if (!mounted) {
      setState(() => _isSaving = false);
      return;
    }
    if (business == null) {
      CustomSnackBar.showError(
        context,
        'Business not found. Please set up a business first.',
      );
      setState(() => _isSaving = false);
      return;
    }

    double creditLimit = 0;
    if (_creditLimitController.text.trim().isNotEmpty) {
      final parsed = double.tryParse(_creditLimitController.text.trim());
      if (parsed == null || parsed < 0) {
        CustomSnackBar.showError(
          context,
          'Credit limit must be a valid non-negative number.',
        );
        setState(() => _isSaving = false);
        return;
      }
      creditLimit = parsed;
    }

    final supplier = Supplier(
      id: widget.supplierId ?? const Uuid().v4(),
      businessId: business.id,
      name: _nameController.text,
      code: _codeController.text,
      taxId: _taxIdController.text.trim().isEmpty
          ? null
          : _taxIdController.text.trim(),
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      contactName: _contactNameController.text.trim().isEmpty
          ? null
          : _contactNameController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty
          ? null
          : _stateController.text.trim(),
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      postalCode: _postalCodeController.text.trim().isEmpty
          ? null
          : _postalCodeController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim().isEmpty
          ? null
          : _paymentTermsController.text.trim(),
      creditLimit: creditLimit,
      currentBalance: _existing?.currentBalance ?? 0,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isActive: _isActive,
      createdAt: _existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      deletedAt: _existing?.deletedAt,
      isDeleted: _existing?.isDeleted ?? false,
      version: _existing?.version ?? 1,
      createdBy: _existing?.createdBy ?? business.id,
      updatedBy: business.id,
    );

    final ctrl = ref.read(supplierListControllerProvider.notifier);
    final result = _isEditMode
        ? await ctrl.update(supplier)
        : await ctrl.create(supplier);

    if (!mounted) return;
    setState(() => _isSaving = false);
    result.fold((_) {
      CustomSnackBar.showSuccess(
        context,
        _isEditMode
            ? 'Supplier updated successfully'
            : 'Supplier created successfully',
      );
      context.pop();
    }, (failure) => CustomSnackBar.showError(context, failure.message));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(
      hasPermissionProvider(AppPermission.manageSuppliers),
    );

    return PermissionGuard(
      permission: AppPermission.manageSuppliers,
      fallback: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'Edit Supplier' : 'New Supplier'),
        ),
        body: const Center(
          child: Text('You do not have permission to manage suppliers.'),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'Edit Supplier' : 'New Supplier'),
          actions: [
            if (_isEditMode && canManage)
              TextButton.icon(
                onPressed: _isLoading || _isSaving
                    ? null
                    : () async {
                        final ctrl = ref.read(
                          supplierListControllerProvider.notifier,
                        );
                        setState(() => _isActive = !_isActive);
                        final res = await ctrl.setActive(
                          widget.supplierId!,
                          _isActive,
                        );
                        res.fold(
                          (_) {
                            if (mounted) {
                              CustomSnackBar.showSuccess(
                                context,
                                _isActive
                                    ? 'Supplier activated'
                                    : 'Supplier deactivated',
                              );
                            }
                          },
                          (f) {
                            if (mounted) {
                              CustomSnackBar.showError(context, f.message);
                            }
                            setState(() => _isActive = !_isActive);
                          },
                        );
                      },
                icon: Icon(
                  _isActive ? Icons.toggle_on : Icons.toggle_off,
                  color: _isActive ? AppColors.success : AppColors.grey500,
                ),
                label: Text(_isActive ? 'Active' : 'Inactive'),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    kToolbarHeight + AppSpacing.xl * 2,
                  ),
                  children: [
                    _SectionHeader(
                      'Business Information',
                      Icons.business_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            label: 'Supplier Name *',
                            hintText: 'e.g. Acme Supplies Ltd',
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                AppValidators.required(v, 'Supplier Name'),
                            enabled: !_isSaving,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            label: 'Supplier Code',
                            hintText: 'Auto-generates if empty',
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            enabled: !_isSaving,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Tax ID / VAT',
                            hintText: 'e.g. PIN / Tax Registration Number',
                            controller: _taxIdController,
                            enabled: !_isSaving,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Website',
                            hintText: 'https://example.com',
                            controller: _websiteController,
                            keyboardType: TextInputType.url,
                            enabled: !_isSaving,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeader('Primary Contact', Icons.person_outline),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Contact Person',
                      hintText: 'e.g. Jane Smith',
                      controller: _contactNameController,
                      textCapitalization: TextCapitalization.words,
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Email Address',
                            hintText: 'supplier@example.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v != null && v.trim().isNotEmpty)
                                ? AppValidators.email(v)
                                : null,
                            enabled: !_isSaving,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Phone Number',
                            hintText: 'e.g. +254 700 000 000',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v != null && v.trim().isNotEmpty)
                                ? AppValidators.phone(v)
                                : null,
                            enabled: !_isSaving,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeader('Address', Icons.location_on_outlined),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Street Address',
                      hintText: 'Physical address',
                      controller: _addressController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'City',
                            hintText: 'City / Town',
                            controller: _cityController,
                            textCapitalization: TextCapitalization.words,
                            enabled: !_isSaving,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'State / Province',
                            hintText: 'State or region',
                            controller: _stateController,
                            textCapitalization: TextCapitalization.words,
                            enabled: !_isSaving,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Country',
                            hintText: 'e.g. Kenya',
                            controller: _countryController,
                            textCapitalization: TextCapitalization.words,
                            enabled: !_isSaving,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Postal Code',
                            hintText: 'e.g. 00100',
                            controller: _postalCodeController,
                            enabled: !_isSaving,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeader('Payment Terms', Icons.payments_outlined),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            label: 'Payment Terms',
                            hintText: 'e.g. Net 30, Due on Receipt',
                            controller: _paymentTermsController,
                            enabled: !_isSaving,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Credit Limit',
                            hintText: '0.00',
                            controller: _creditLimitController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            prefix: const Text('\$'),
                            enabled: !_isSaving,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionHeader('Notes', Icons.sticky_note_2_outlined),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Additional Notes',
                      hintText: 'Any special instructions or comments...',
                      controller: _notesController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isSaving,
                    ),
                    if (_isEditMode) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _AuditInfo(existing: _existing),
                    ],
                  ],
                ),
              ),
        bottomNavigationBar: canManage
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppOutlineButton(
                          text: 'Cancel',
                          onPressed: _isSaving ? null : () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          text: _isEditMode
                              ? 'Update Supplier'
                              : 'Create Supplier',
                          backgroundColor: _isEditMode
                              ? AppColors.secondary
                              : AppColors.primary,
                          isLoading: _isSaving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: AppRadius.borderRadiusMd,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(title, style: AppTextStyles.subtitle),
      ],
    );
  }
}

class _AuditInfo extends StatelessWidget {
  final Supplier? existing;
  const _AuditInfo({this.existing});

  @override
  Widget build(BuildContext context) {
    if (existing == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: AppRadius.borderRadiusLg,
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audit',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _AuditCell(
                  'Created',
                  existing!.createdAt.toLocal().toString().substring(0, 16),
                ),
              ),
              Expanded(
                child: _AuditCell(
                  'Updated',
                  existing!.updatedAt.toLocal().toString().substring(0, 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _AuditCell('Version', 'v${existing!.version}')),
              Expanded(
                child: _AuditCell(
                  'Balance',
                  '\$${existing!.currentBalance.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditCell extends StatelessWidget {
  final String label;
  final String value;
  const _AuditCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
          ),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
