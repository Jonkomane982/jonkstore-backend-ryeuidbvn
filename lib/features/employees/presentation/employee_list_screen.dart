import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/employees/controllers/employee_controller.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(employeeControllerProvider.notifier).loadEmployees(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
      ),
      body: _buildContent(state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('${RouteNames.employees}-add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Employee', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildContent(EmployeeState state) {
    if (state.isLoading) return const Center(child: AppLoadingIndicator());
    if (state.errorMessage != null) return Center(child: Text(state.errorMessage!));

    if (state.employees.isEmpty) {
      return const EmptyState(
        title: 'No Employees',
        message: 'Add staff members and assign roles to manage your store.',
        icon: Icons.badge_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.employees.length,
      itemBuilder: (context, index) {
        final employee = state.employees[index];
        return Card(
          child: ListTile(
            onTap: () => context.pushNamed(
              '${RouteNames.employees}-edit',
              pathParameters: {'id': employee.id},
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.person_outline, color: AppColors.primary),
            ),
            title: Text(employee.designation, style: AppTextStyles.subtitle),
            subtitle: Text('Code: ${employee.employeeCode}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: employee.isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                employee.isActive ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                  color: employee.isActive ? AppColors.success : AppColors.error,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
