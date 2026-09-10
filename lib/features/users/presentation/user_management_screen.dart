import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/domain/enums/user_role.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/buttons/primary_button.dart';
import '../../../shared/loading/loading_indicator.dart';
import '../../../shared/snackbars/custom_snack_bar.dart';
import '../controllers/admin_users_controller.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(adminUsersControllerProvider.notifier).loadUsers(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersControllerProvider);

    ref.listen<AdminUsersState>(adminUsersControllerProvider, (prev, next) {
      if (next.errorMessage != null) {
        CustomSnackBar.showError(context, next.errorMessage!);
        ref.read(adminUsersControllerProvider.notifier).clearMessages();
      } else if (next.successMessage != null) {
        CustomSnackBar.showSuccess(context, next.successMessage!);
        ref.read(adminUsersControllerProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.goNamed(RouteNames.dashboard);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchAndFilters(state),
            const Divider(height: 1),
            Expanded(child: _buildContent(state)),
            _buildPagination(state),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(AdminUsersState state) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Search by email or name',
                    border: const OutlineInputBorder(),
                    suffixIcon: state.searchQuery != null && state.searchQuery!.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(adminUsersControllerProvider.notifier)
                                  .setFilters(search: '');
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (v) {
                    ref.read(adminUsersControllerProvider.notifier)
                        .setFilters(search: v.trim().isEmpty ? null : v.trim());
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PrimaryButton(
                text: 'Search',
                onPressed: () {
                  ref.read(adminUsersControllerProvider.notifier)
                      .setFilters(search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim());
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Role Filter', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _filterChip(
                label: 'All',
                selected: state.filterRole == null,
                onTap: () => ref.read(adminUsersControllerProvider.notifier)
                    .setFilters(clearRole: true),
              ),
              ...UserRole.values.map((r) => _filterChip(
                    label: _roleLabel(r),
                    selected: state.filterRole == r,
                    color: _roleColor(r),
                    onTap: () => ref.read(adminUsersControllerProvider.notifier)
                        .setFilters(role: state.filterRole == r ? null : r),
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Status Filter', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _filterChip(
                label: 'All',
                selected: state.filterStatus == null,
                onTap: () => ref.read(adminUsersControllerProvider.notifier)
                    .setFilters(clearStatus: true),
              ),
              ...AccountStatus.values.map((s) => _filterChip(
                    label: _statusLabel(s),
                    selected: state.filterStatus == s,
                    color: _statusColor(s),
                    onTap: () => ref.read(adminUsersControllerProvider.notifier)
                        .setFilters(status: state.filterStatus == s ? null : s),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: (color ?? AppColors.primary).withOpacity(0.2),
      checkmarkColor: color ?? AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? (color ?? AppColors.primary) : null,
        fontWeight: selected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildContent(AdminUsersState state) {
    if (state.isLoading && state.users.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 80, color: AppColors.primary.withOpacity(0.3)),
              const SizedBox(height: AppSpacing.md),
              Text('No users found', style: AppTextStyles.subtitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.searchQuery != null || state.filterRole != null || state.filterStatus != null
                    ? 'Try adjusting your filters.'
                    : 'New accounts will appear here as users register.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(adminUsersControllerProvider.notifier).loadUsers(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.users.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final user = state.users[index];
          return _UserCard(
            user: user,
            onActivate: () => ref.read(adminUsersControllerProvider.notifier)
                .updateStatus(user.id, AccountStatus.active),
            onSuspend: () => ref.read(adminUsersControllerProvider.notifier)
                .updateStatus(user.id, AccountStatus.suspended),
            onMarkPending: () => ref.read(adminUsersControllerProvider.notifier)
                .updateStatus(user.id, AccountStatus.pending),
            onChangeRole: (role) => ref.read(adminUsersControllerProvider.notifier)
                .updateRole(user.id, role),
            onDelete: () => _confirmDelete(user),
          );
        },
      ),
    );
  }

  Widget _buildPagination(AdminUsersState state) {
    if (state.totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page ${state.currentPage} of ${state.totalPages} • ${state.total} users',
            style: AppTextStyles.caption,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: state.currentPage > 1
                    ? () => ref.read(adminUsersControllerProvider.notifier).goToPage(1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: state.currentPage > 1
                    ? () => ref.read(adminUsersControllerProvider.notifier)
                        .goToPage(state.currentPage - 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: state.currentPage < state.totalPages
                    ? () => ref.read(adminUsersControllerProvider.notifier)
                        .goToPage(state.currentPage + 1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: state.currentPage < state.totalPages
                    ? () => ref.read(adminUsersControllerProvider.notifier)
                        .goToPage(state.totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AdminUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to permanently delete ${user.email}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(adminUsersControllerProvider.notifier).deleteUser(user.id);
    }
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onActivate;
  final VoidCallback onSuspend;
  final VoidCallback onMarkPending;
  final ValueChanged<UserRole> onChangeRole;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onActivate,
    required this.onSuspend,
    required this.onMarkPending,
    required this.onChangeRole,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _roleColor(user.role).withOpacity(0.15),
                  child: Text(
                    (user.username.isEmpty ? user.email : user.username)
                        .characters
                        .first
                        .toUpperCase(),
                    style: TextStyle(
                      color: _roleColor(user.role),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.username.isEmpty ? user.email : user.username,
                              style: AppTextStyles.subtitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusBadge(status: user.accountStatus),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(user.email, style: AppTextStyles.body),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          _RoleBadge(role: user.role),
                          const SizedBox(width: AppSpacing.sm),
                          if (user.lastLoginAt != null)
                            Text(
                              'Last login: ${_formatDate(user.lastLoginAt!)}',
                              style: AppTextStyles.caption,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Created: ${_formatDate(user.createdAt)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'activate':
                        onActivate();
                        break;
                      case 'suspend':
                        onSuspend();
                        break;
                      case 'pending':
                        onMarkPending();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      default:
                        if (v.startsWith('role:')) {
                          final roleName = v.substring(5);
                          final role = UserRole.values.firstWhere(
                            (r) => r.name == roleName,
                            orElse: () => UserRole.cashier,
                          );
                          onChangeRole(role);
                        }
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'activate',
                      enabled: user.accountStatus != AccountStatus.active,
                      child: const ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.check_circle, color: AppColors.success),
                        title: Text('Activate'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'suspend',
                      enabled: user.accountStatus != AccountStatus.suspended,
                      child: const ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.block, color: AppColors.error),
                        title: Text('Suspend'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pending',
                      enabled: user.accountStatus != AccountStatus.pending,
                      child: const ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.pause_circle, color: Colors.orange),
                        title: Text('Mark as Pending'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      enabled: false,
                      child: Text('Change Role', style: AppTextStyles.caption),
                    ),
                    ...UserRole.values.map((r) => PopupMenuItem(
                          value: 'role:${r.name}',
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.shield_outlined,
                              color: user.role == r ? _roleColor(r) : Colors.grey,
                            ),
                            title: Text(_roleLabel(r)),
                            trailing: user.role == r ? const Icon(Icons.check) : null,
                          ),
                        )),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_forever, color: AppColors.error),
                        title: const Text('Delete User', style: TextStyle(color: AppColors.error)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AccountStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: _statusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _roleColor(role).withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _roleLabel(role).toUpperCase(),
        style: TextStyle(
          color: _roleColor(role),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

Color _roleColor(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return Colors.red;
    case UserRole.owner:
      return Colors.purple;
    case UserRole.manager:
      return Colors.indigo;
    case UserRole.cashier:
      return Colors.teal;
    case UserRole.storeAssistant:
      return Colors.blueGrey;
  }
}

Color _statusColor(AccountStatus s) {
  switch (s) {
    case AccountStatus.active:
      return AppColors.success;
    case AccountStatus.pending:
      return Colors.orange;
    case AccountStatus.suspended:
      return AppColors.error;
  }
}

String _roleLabel(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.owner:
      return 'Owner';
    case UserRole.manager:
      return 'Manager';
    case UserRole.cashier:
      return 'Cashier';
    case UserRole.storeAssistant:
      return 'Store Assistant';
  }
}

String _statusLabel(AccountStatus s) {
  switch (s) {
    case AccountStatus.active:
      return 'Active';
    case AccountStatus.pending:
      return 'Pending';
    case AccountStatus.suspended:
      return 'Suspended';
  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '—';
  final d = dt.toLocal();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final yyyy = d.year.toString();
  final hh = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd $hh:$min';
}
