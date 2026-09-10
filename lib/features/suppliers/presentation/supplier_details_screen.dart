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
import 'package:jonkstore/core/helpers/currency_formatter.dart';
import 'package:jonkstore/core/helpers/date_formatter.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/suppliers/controllers/supplier_list_controller.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/shared/cards/primary_card.dart';
import 'package:jonkstore/shared/dialogs/confirmation_dialog.dart';
import 'package:jonkstore/shared/guards/permission_guard.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';

class SupplierDetailsScreen extends ConsumerStatefulWidget {
  final String supplierId;
  const SupplierDetailsScreen({super.key, required this.supplierId});

  @override
  ConsumerState<SupplierDetailsScreen> createState() =>
      _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends ConsumerState<SupplierDetailsScreen> {
  late Future<Result<Supplier?>> _supplierFuture;
  late Future<Result<int>> _productsCountFuture;
  late Future<Result<Map<String, double>>> _totalsFuture;
  late Future<Result<List<Map<String, dynamic>>>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    final repo = ref.read(supplierRepositoryProvider);
    _supplierFuture = repo.findById(widget.supplierId);
    _productsCountFuture = repo.countProductsForSupplier(widget.supplierId);
    _totalsFuture = repo.getPurchaseTotals(widget.supplierId);
    _recentFuture = repo.getRecentPurchases(widget.supplierId, limit: 15);
  }

  Future<void> _refresh() async {
    setState(_loadAll);
    await Future.wait([
      _supplierFuture,
      _productsCountFuture,
      _totalsFuture,
      _recentFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(
      hasPermissionProvider(AppPermission.manageSuppliers),
    );
    final ctrl = ref.read(supplierListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
          PermissionGuard(
            permission: AppPermission.manageSuppliers,
            child: PopupMenuButton<String>(
              onSelected: (v) async {
                final snap = await _supplierFuture;
                final supplier = snap.value;
                if (supplier == null || !mounted) return;
                switch (v) {
                  case 'edit':
                    context
                        .pushNamed(
                          '${RouteNames.suppliers}-edit',
                          pathParameters: {'id': widget.supplierId},
                        )
                        .then((_) => _refresh());
                    break;
                  case 'toggle':
                    final res = await ctrl.setActive(
                      widget.supplierId,
                      !supplier.isActive,
                    );
                    res.fold(
                      (_) {
                        if (mounted) {
                          CustomSnackBar.showSuccess(
                            context,
                            supplier.isActive
                                ? 'Supplier deactivated'
                                : 'Supplier activated',
                          );
                        }
                        _refresh();
                      },
                      (f) {
                        if (mounted) {
                          CustomSnackBar.showError(context, f.message);
                        }
                      },
                    );
                    break;
                  case 'delete':
                    if (supplier.isDeleted) {
                      ConfirmationDialog.show(
                        context,
                        title: 'Remove Supplier?',
                        message:
                            'This will permanently remove the supplier record.',
                        confirmLabel: 'Remove',
                        isDanger: true,
                        onConfirm: () async {
                          final res = await ctrl.delete(widget.supplierId);
                          res.fold(
                            (_) {
                              if (mounted) {
                                CustomSnackBar.showSuccess(
                                  context,
                                  'Supplier removed',
                                );
                                context.pop();
                              }
                            },
                            (f) {
                              if (mounted) {
                                CustomSnackBar.showError(context, f.message);
                              }
                            },
                          );
                        },
                      );
                    } else {
                      ConfirmationDialog.show(
                        context,
                        title: 'Delete Supplier?',
                        message:
                            'This will soft-delete the supplier. You can restore them later from the supplier list.',
                        confirmLabel: 'Delete',
                        isDanger: true,
                        onConfirm: () async {
                          final res = await ctrl.delete(widget.supplierId);
                          res.fold(
                            (_) {
                              if (mounted) {
                                CustomSnackBar.showSuccess(
                                  context,
                                  'Supplier deleted',
                                );
                                _refresh();
                              }
                            },
                            (f) {
                              if (mounted) {
                                CustomSnackBar.showError(context, f.message);
                              }
                            },
                          );
                        },
                      );
                    }
                    break;
                  case 'restore':
                    ConfirmationDialog.show(
                      context,
                      title: 'Restore Supplier?',
                      message:
                          'This will restore the supplier and make them available again.',
                      confirmLabel: 'Restore',
                      onConfirm: () async {
                        final res = await ctrl.restore(widget.supplierId);
                        res.fold(
                          (_) {
                            if (mounted) {
                              CustomSnackBar.showSuccess(
                                context,
                                'Supplier restored',
                              );
                              _refresh();
                            }
                          },
                          (f) {
                            if (mounted) {
                              CustomSnackBar.showError(context, f.message);
                            }
                          },
                        );
                      },
                    );
                    break;
                }
              },
              itemBuilder: (_) {
                return [
                  if (canManage)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  if (canManage)
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: FutureBuilder<Result<Supplier?>>(
                        future: _supplierFuture,
                        builder: (_, s) {
                          final active = s.data?.value?.isActive ?? true;
                          return Row(
                            children: [
                              Icon(
                                active
                                    ? Icons.block
                                    : Icons.check_circle_outline,
                              ),
                              const SizedBox(width: 8),
                              Text(active ? 'Deactivate' : 'Activate'),
                            ],
                          );
                        },
                      ),
                    ),
                  if (canManage)
                    PopupMenuItem<String>(
                      value: 'restore',
                      enabled: true,
                      child: const Row(
                        children: [
                          Icon(Icons.restore_from_trash_outlined),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                  if (canManage)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.error),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Result<Supplier?>>(
          future: _supplierFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done || !snap.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            final res = snap.data!;
            return res.fold((supplier) {
              if (supplier == null) {
                return Center(
                  child: EmptyState(
                    title: 'Supplier not found',
                    message: 'This supplier may have been removed.',
                    icon: Icons.business,
                  ),
                );
              }
              return _DetailView(
                supplier: supplier,
                productsCountFuture: _productsCountFuture,
                totalsFuture: _totalsFuture,
                recentFuture: _recentFuture,
                canManage: canManage,
                onEdit: () => context
                    .pushNamed(
                      '${RouteNames.suppliers}-edit',
                      pathParameters: {'id': widget.supplierId},
                    )
                    .then((_) => _refresh()),
              );
            }, (f) => Center(child: Text(f.message)));
          },
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  final Supplier supplier;
  final Future<Result<int>> productsCountFuture;
  final Future<Result<Map<String, double>>> totalsFuture;
  final Future<Result<List<Map<String, dynamic>>>> recentFuture;
  final bool canManage;
  final VoidCallback onEdit;

  const _DetailView({
    required this.supplier,
    required this.productsCountFuture,
    required this.totalsFuture,
    required this.recentFuture,
    required this.canManage,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        PrimaryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
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
                          ? Icons.delete_sweep
                          : Icons.business_rounded,
                      size: 28,
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
                                style: AppTextStyles.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _StatusBadge(supplier: supplier),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (supplier.code.isNotEmpty)
                          Text(
                            'Code: ${supplier.code}',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.grey500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  _InfoRow(
                    Icons.person_outline,
                    'Contact',
                    supplier.contactName,
                  ),
                  _InfoRow(Icons.phone_outlined, 'Phone', supplier.phone),
                  _InfoRow(Icons.email_outlined, 'Email', supplier.email),
                  _InfoRow(
                    Icons.language_outlined,
                    'Website',
                    supplier.website,
                  ),
                  _InfoRow(
                    Icons.receipt_long_outlined,
                    'Tax ID',
                    supplier.taxId,
                  ),
                  _InfoRow(
                    Icons.schedule_outlined,
                    'Terms',
                    supplier.paymentTerms,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: AppSpacing.md),
              _FullAddress(supplier: supplier),
              if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.grey100.withValues(alpha: isDark ? 0.2 : 1),
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 16,
                            color: AppColors.grey500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Notes',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(supplier.notes!, style: AppTextStyles.body),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (canManage)
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: PermissionGuard(
                      permission: AppPermission.manageSuppliers,
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Supplier'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<Result<Map<String, double>>>(
          future: totalsFuture,
          builder: (_, snap) {
            final totals =
                snap.data?.value ??
                <String, double>{
                  'total_purchase_value': 0.0,
                  'total_paid': 0.0,
                  'outstanding_balance': 0.0,
                  'purchase_count': 0.0,
                };
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Purchases',
                        value: CurrencyFormatter.format(
                          (totals['total_purchase_value'] as num?)?.toDouble() ?? 0.0,
                        ),
                        icon: Icons.point_of_sale_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        title: 'Paid',
                        value: CurrencyFormatter.format(
                          (totals['total_paid'] as num?)?.toDouble() ?? 0.0,
                        ),
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Outstanding',
                        value: CurrencyFormatter.format(
                          ((totals['outstanding_balance'] as num?)?.toDouble() ?? 0.0) +
                              supplier.currentBalance,
                        ),
                        icon: Icons.payments_outlined,
                        color:
                            (((totals['outstanding_balance'] as num?)?.toDouble() ?? 0.0) +
                                    supplier.currentBalance) >
                                0
                            ? AppColors.error
                            : AppColors.grey500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        title: 'Credit Limit',
                        value: CurrencyFormatter.format(supplier.creditLimit),
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Products Supplied',
                      style: AppTextStyles.subtitle,
                    ),
                  ),
                  FutureBuilder<Result<int>>(
                    future: productsCountFuture,
                    builder: (_, snap) {
                      final n = snap.data?.value ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadius.borderRadiusSm,
                        ),
                        child: Text(
                          '$n',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<Result<int>>(
                future: productsCountFuture,
                builder: (_, snap) {
                  final count = snap.data?.value ?? 0;
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: AppLoadingIndicator(),
                      ),
                    );
                  }
                  if (count == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 40,
                              color: AppColors.grey400,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No products linked to this supplier yet.',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Text(
                    '$count product${count == 1 ? '' : 's'} supplied.',
                    style: AppTextStyles.body,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent Transactions',
                      style: AppTextStyles.subtitle,
                    ),
                  ),
                  FutureBuilder<Result<Map<String, double>>>(
                    future: totalsFuture,
                    builder: (_, snap) {
                      final count = (snap.data?.value['purchase_count'] as num? ?? 0.0)
                          .toInt();
                      return Text(
                        '$count order${count == 1 ? '' : 's'}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.grey500,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FutureBuilder<Result<List<Map<String, dynamic>>>>(
                future: recentFuture,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: AppLoadingIndicator(),
                      ),
                    );
                  }
                  final list =
                      snap.data?.value ?? const <Map<String, dynamic>>[];
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: AppColors.grey400,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No purchase orders yet.',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.grey500,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Purchase orders from this supplier will appear here.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.grey400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _PurchaseTile(data: list[i]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
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
        vertical: 4,
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final v = value!;
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.grey500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.grey500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(v, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FullAddress extends StatelessWidget {
  final Supplier supplier;
  const _FullAddress({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (supplier.address != null && supplier.address!.isNotEmpty) {
      parts.add(supplier.address!);
    }
    final cityRegion = <String>[];
    if (supplier.city != null && supplier.city!.isNotEmpty) {
      cityRegion.add(supplier.city!);
    }
    if (supplier.state != null && supplier.state!.isNotEmpty) {
      cityRegion.add(supplier.state!);
    }
    if (supplier.postalCode != null && supplier.postalCode!.isNotEmpty) {
      cityRegion.add(supplier.postalCode!);
    }
    if (cityRegion.isNotEmpty) parts.add(cityRegion.join(', '));
    if (supplier.country != null && supplier.country!.isNotEmpty) {
      parts.add(supplier.country!);
    }

    if (parts.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 16,
          color: AppColors.grey500,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Address',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
              ),
              const SizedBox(height: 2),
              Text(parts.join('\n'), style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusLg,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.caption.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.subtitle.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PurchaseTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final orderNumber = data['order_number']?.toString() ?? 'PO-UNKNOWN';
    final rawDate = data['purchase_date'];
    final date = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;
    final status = (data['status']?.toString() ?? 'pending').toLowerCase();
    final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paid = (data['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (total - paid).clamp(0.0, double.infinity).toDouble();

    Color statusBg;
    Color statusFg;
    switch (status) {
      case 'received':
      case 'completed':
        statusBg = AppColors.successLight;
        statusFg = AppColors.successDark;
        break;
      case 'cancelled':
      case 'canceled':
        statusBg = AppColors.errorLight;
        statusFg = AppColors.errorDark;
        break;
      case 'pending':
      default:
        statusBg = AppColors.warningLight;
        statusFg = AppColors.warningDark;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondaryLight,
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.secondary,
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
                        orderNumber,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: AppTextStyles.caption.copyWith(
                          color: statusFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        date != null
                            ? DateFormatter.formatShortDate(date)
                            : 'No date',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.grey500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      CurrencyFormatter.format(total),
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (outstanding > 0)
                      Text(
                        '· ${CurrencyFormatter.format(outstanding)} due',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
