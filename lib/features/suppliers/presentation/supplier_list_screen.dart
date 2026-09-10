import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_radius.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/auth/app_permission.dart';
import 'package:jonkstore/core/auth/permission_provider.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/core/helpers/date_formatter.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/suppliers/controllers/supplier_list_controller.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';
import 'package:jonkstore/shared/dialogs/confirmation_dialog.dart';
import 'package:jonkstore/shared/guards/permission_guard.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/shared/textfields/search_text_field.dart';

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final _searchController = TextEditingController();
  bool _showDeleted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierListControllerProvider);
    final ctrl = ref.read(supplierListControllerProvider.notifier);
    final canManage = ref.watch(
      hasPermissionProvider(AppPermission.manageSuppliers),
    );

    ref.listen<SupplierListState>(supplierListControllerProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            CustomSnackBar.showError(context, next.errorMessage!);
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  ctrl.load();
                  break;
                case 'deleted':
                  setState(() => _showDeleted = !_showDeleted);
                  ctrl.load();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deleted',
                child: Row(
                  children: [
                    Icon(
                      _showDeleted ? Icons.visibility_off : Icons.visibility,
                    ),
                    const SizedBox(width: 8),
                    Text(_showDeleted ? 'Hide Deleted' : 'Show Deleted'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SearchTextField(
              controller: _searchController,
              hintText: 'Search name, code, contact, phone...',
              onChanged: ctrl.updateSearch,
              onClear: () {
                _searchController.clear();
                ctrl.updateSearch('');
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: state.isActiveFilter == null,
                  onTap: () => ctrl.filterActive(null),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Active',
                  selected: state.isActiveFilter == true,
                  onTap: () => ctrl.filterActive(true),
                  active: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Inactive',
                  selected: state.isActiveFilter == false,
                  onTap: () => ctrl.filterActive(false),
                  active: false,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Sort by',
                  icon: const Icon(Icons.sort),
                  onSelected: ctrl.sortBy,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'name', child: Text('Name')),
                    const PopupMenuItem(value: 'code', child: Text('Code')),
                    const PopupMenuItem(
                      value: 'created_at',
                      child: Text('Date Created'),
                    ),
                    const PopupMenuItem(
                      value: 'updated_at',
                      child: Text('Last Updated'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (state.totalCount != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${state.totalCount} supplier${state.totalCount == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.grey500,
                  ),
                ),
              ),
            ),
          Expanded(child: _buildContent(state, canManage, ctrl)),
        ],
      ),
      floatingActionButton: PermissionGuard(
        permission: AppPermission.manageSuppliers,
        child: FloatingActionButton.extended(
          onPressed: () => context.pushNamed('${RouteNames.suppliers}-add'),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_business_rounded, color: Colors.white),
          label: const Text(
            'Add Supplier',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    SupplierListState state,
    bool canManage,
    SupplierListController ctrl,
  ) {
    if (state.isLoading && state.suppliers.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.suppliers.isEmpty) {
      final isSearching = state.searchQuery.trim().isNotEmpty;
      final isFiltered = state.isActiveFilter != null;
      return EmptyState(
        title: isSearching
            ? 'No matching suppliers'
            : (isFiltered
                  ? 'No suppliers in this filter'
                  : (_showDeleted
                        ? 'No deleted suppliers'
                        : 'No suppliers yet')),
        message: isSearching || isFiltered
            ? 'Try adjusting your search or filter.'
            : 'Add suppliers to start tracking procurement relationships.',
        icon: Icons.business_outlined,
        actionLabel: canManage && !isSearching && !isFiltered && !_showDeleted
            ? 'Add Supplier'
            : null,
        onActionPressed: canManage
            ? () => context.pushNamed('${RouteNames.suppliers}-add')
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          kToolbarHeight + AppSpacing.xl,
        ),
        itemCount: state.suppliers.length,
        itemBuilder: (ctx, i) {
          final s = state.suppliers[i];
          return _SupplierTile(
            supplier: s,
            canManage: canManage,
            onTap: () => context.pushNamed(
              RouteNames.supplierDetails,
              pathParameters: {'id': s.id},
            ),
            onEdit: () => context.pushNamed(
              '${RouteNames.suppliers}-edit',
              pathParameters: {'id': s.id},
            ),
            onToggleActive: (v) async {
              final res = await ctrl.setActive(s.id, v);
              res.fold(
                (_) {
                  if (mounted) {
                    CustomSnackBar.showSuccess(
                      context,
                      v ? 'Supplier activated' : 'Supplier deactivated',
                    );
                  }
                },
                (f) {
                  /* listened above */
                },
              );
            },
            onDelete: () => ConfirmationDialog.show(
              context,
              title: s.isDeleted ? 'Permanently Remove?' : 'Delete Supplier?',
              message: s.isDeleted
                  ? 'This will permanently remove the supplier record.'
                  : 'This supplier will be soft-deleted. You can restore it later.',
              confirmLabel: s.isDeleted ? 'Remove' : 'Delete',
              isDanger: true,
              onConfirm: () async {
                final res = await ctrl.delete(s.id);
                res.fold(
                  (_) {
                    if (mounted) {
                      CustomSnackBar.showSuccess(context, 'Supplier deleted');
                    }
                  },
                  (_) {
                    /* listened */
                  },
                );
              },
            ),
            onRestore: () => ConfirmationDialog.show(
              context,
              title: 'Restore Supplier?',
              message:
                  'The supplier will be restored to active suppliers list.',
              confirmLabel: 'Restore',
              onConfirm: () async {
                final res = await ctrl.restore(s.id);
                res.fold(
                  (_) {
                    if (mounted) {
                      CustomSnackBar.showSuccess(context, 'Supplier restored');
                    }
                  },
                  (_) {
                    /* listened */
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool? active;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.active,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (active == null
              ? AppColors.primary
              : active!
              ? AppColors.success
              : AppColors.grey700)
        : Theme.of(context).colorScheme.surface;
    final fg = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: bg,
      borderRadius: AppRadius.borderRadiusPill,
      child: InkWell(
        borderRadius: AppRadius.borderRadiusPill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderRadiusPill,
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  const _SupplierTile({
    required this.supplier,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[];
    if (supplier.code.isNotEmpty) subtitle.add(supplier.code);
    if (supplier.contactName != null && supplier.contactName!.isNotEmpty) {
      subtitle.add(supplier.contactName!);
    }
    if (supplier.phone != null && supplier.phone!.isNotEmpty) {
      subtitle.add(supplier.phone!);
    }
    if (supplier.email != null && supplier.email!.isNotEmpty) {
      subtitle.add(supplier.email!);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dim = supplier.isDeleted || !supplier.isActive;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: PrimaryCard(
        padding: EdgeInsets.zero,
        borderSide: supplier.isDeleted
            ? BorderSide(
                color: isDark ? AppColors.grey700 : AppColors.grey300,
                style: BorderStyle.solid,
              )
            : null,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.borderRadiusLg,
          child: InkWell(
            borderRadius: AppRadius.borderRadiusLg,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              (supplier.isDeleted
                                      ? AppColors.grey400
                                      : supplier.isActive
                                      ? AppColors.secondary
                                      : AppColors.warning)
                                  .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          supplier.isDeleted
                              ? Icons.delete_sweep_outlined
                              : Icons.business_rounded,
                          color: supplier.isDeleted
                              ? AppColors.grey500
                              : supplier.isActive
                              ? AppColors.secondary
                              : AppColors.warning,
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
                                    supplier.name,
                                    style: AppTextStyles.subtitle.copyWith(
                                      color: dim
                                          ? (isDark
                                                ? AppColors.grey500
                                                : AppColors.grey500)
                                          : null,
                                      decoration: supplier.isDeleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                _StatusBadge(supplier: supplier),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (subtitle.isNotEmpty)
                              Text(
                                subtitle.join(' · '),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.grey500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _InfoChip(
                              icon: Icons.calendar_today_outlined,
                              text: DateFormatter.formatShortDate(
                                supplier.createdAt,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canManage) ...[
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        if (!supplier.isDeleted)
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'toggle':
                                  onToggleActive(!supplier.isActive);
                                  break;
                                case 'delete':
                                  onDelete();
                                  break;
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      supplier.isActive
                                          ? Icons.block
                                          : Icons.check_circle_outline,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      supplier.isActive
                                          ? 'Deactivate'
                                          : 'Activate',
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else
                          IconButton(
                            tooltip: 'Restore',
                            onPressed: onRestore,
                            color: AppColors.success,
                            icon: const Icon(Icons.restore_from_trash_outlined),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Supplier supplier;
  const _StatusBadge({required this.supplier});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    if (supplier.isDeleted) {
      label = 'Deleted';
      bg = AppColors.grey200;
      fg = AppColors.grey700;
    } else if (supplier.isActive) {
      label = 'Active';
      bg = AppColors.successLight;
      fg = AppColors.successDark;
    } else {
      label = 'Inactive';
      bg = AppColors.warningLight;
      fg = AppColors.warningDark;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderRadiusSm,
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.grey500),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
          ),
        ),
      ],
    );
  }
}
