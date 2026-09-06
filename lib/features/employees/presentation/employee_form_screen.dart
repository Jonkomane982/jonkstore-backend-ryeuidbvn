import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/employee.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/domain/enums/user_role.dart';
import 'package:jonkstore/core/validators/app_validators.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/textfields/app_text_field.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/features/employees/controllers/employee_controller.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;

  const EmployeeFormScreen({super.key, this.employeeId});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _codeController = TextEditingController();
  final _designationController = TextEditingController();
  final _salaryController = TextEditingController();
  
  UserRole _selectedRole = UserRole.cashier;
  bool _isActive = true;
  bool _isEditMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.employeeId != null;
    if (_isEditMode) {
      _loadEmployee();
    }
  }

  Future<void> _loadEmployee() async {
    setState(() => _isLoading = true);
    final repo = ref.read(employeeRepositoryProvider);
    final result = await repo.findById(widget.employeeId!);
    
    result.fold(
      (employee) {
        if (employee != null) {
          _codeController.text = employee.employeeCode;
          _designationController.text = employee.designation;
          _salaryController.text = employee.salary?.toString() ?? '';
          setState(() {
            _isActive = employee.isActive;
            _isLoading = false;
          });
        }
      },
      (failure) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(context, failure.message);
      },
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _designationController.dispose();
    _salaryController.dispose();
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

    final employee = Employee(
      id: widget.employeeId ?? const Uuid().v4(),
      userId: 'unlinked', 
      businessId: business.id,
      branchId: business.id,
      employeeCode: _codeController.text.trim(),
      designation: _designationController.text.trim(),
      salary: double.tryParse(_salaryController.text),
      isActive: _isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    final repo = ref.read(employeeRepositoryProvider);
    final result = _isEditMode ? await repo.update(employee) : await repo.create(employee);

    result.fold(
      (success) {
        CustomSnackBar.showSuccess(context, 'Employee record saved');
        ref.read(employeeControllerProvider.notifier).loadEmployees();
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
        title: Text(_isEditMode ? 'Edit Employee' : 'Add Employee'),
      ),
      body: _isLoading && _isEditMode 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Employee Code *',
                hintText: 'e.g. EMP001',
                controller: _codeController,
                validator: (v) => AppValidators.required(v, 'Employee Code'),
              ),
              const SizedBox(height: AppSpacing.md),
              
              AppTextField(
                label: 'Designation / Job Title *',
                hintText: 'e.g. Senior Cashier',
                controller: _designationController,
                validator: (v) => AppValidators.required(v, 'Designation'),
              ),
              const SizedBox(height: AppSpacing.md),

              Text('Assigned Role', style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                items: [
                  UserRole.manager,
                  UserRole.cashier,
                  UserRole.storeAssistant,
                ].map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.name.toUpperCase()),
                )).toList(),
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                label: 'Monthly Salary',
                hintText: '0.00',
                controller: _salaryController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),

              SwitchListTile(
                title: const Text('Active Status'),
                subtitle: const Text('Allow this employee to access the POS system'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                text: _isEditMode ? 'Update Employee' : 'Add Employee',
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
