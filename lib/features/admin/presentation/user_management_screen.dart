import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/domain/models/owner_profile.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/providers/owner_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  bool _isLoading = false;
  List<OwnerProfile> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final result = await ref.read(ownerServiceProvider).listAllAccounts();
    result.fold(
      (list) => setState(() => _users = list),
      (failure) => CustomSnackBar.showError(context, failure.message),
    );
    setState(() => _isLoading = false);
  }

  Future<void> _updateStatus(String userId, String status) async {
    final result = await ref.read(ownerServiceProvider).updateAccountStatus(userId, status);
    result.fold(
      (_) {
        CustomSnackBar.showSuccess(context, 'Status updated to $status');
        _fetchUsers();
      },
      (failure) => CustomSnackBar.showError(context, failure.message),
    );
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ref.read(ownerServiceProvider).deleteAccount(userId);
      result.fold(
        (_) => _fetchUsers(),
        (failure) => CustomSnackBar.showError(context, failure.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: _isLoading 
        ? const Center(child: AppLoadingIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final user = _users[index];
              final isAdmin = user.role.name == 'ADMIN';

              return Card(
                child: ListTile(
                  title: Text(user.username, style: AppTextStyles.subtitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.email),
                      _StatusChip(status: user.accountStatus.name),
                    ],
                  ),
                  trailing: isAdmin ? const Icon(Icons.security, color: AppColors.primary) : PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'delete') _deleteUser(user.id);
                      else _updateStatus(user.id, val);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'active', child: Text('Activate')),
                      const PopupMenuItem(value: 'suspended', child: Text('Suspend')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Account')),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.grey500;
    if (status == 'active') color = AppColors.success;
    if (status == 'pending') color = AppColors.warning;
    if (status == 'suspended') color = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
