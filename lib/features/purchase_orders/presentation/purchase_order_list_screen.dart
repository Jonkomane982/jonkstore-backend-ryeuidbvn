import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/routing/route_names.dart';
import 'package:jonkstore/features/purchase_orders/controllers/purchase_controller.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/loading/empty_state.dart';

class PurchaseOrderListScreen extends ConsumerStatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  ConsumerState<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends ConsumerState<PurchaseOrderListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(purchaseControllerProvider.notifier).loadOrders(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
      ),
      body: _buildContent(state),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('${RouteNames.purchaseOrders}-add'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Order', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildContent(PurchaseState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (state.errorMessage != null) {
      return Center(child: Text(state.errorMessage!));
    }

    if (state.orders.isEmpty) {
      return const EmptyState(
        title: 'No Purchase Orders',
        message: 'Manage your stock procurement by creating purchase orders.',
        icon: Icons.local_shipping_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.orders.length,
      itemBuilder: (context, index) {
        final order = state.orders[index];
        final isReceived = order.status == 'received';

        return Card(
          child: ListTile(
            onTap: () => context.pushNamed(
              '${RouteNames.purchaseOrders}-details',
              pathParameters: {'id': order.id},
            ),
            title: Text(order.orderNumber ?? 'No Order #', style: AppTextStyles.subtitle),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('dd MMM yyyy').format(order.orderDate)),
                _StatusChip(status: order.status),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES ${order.totalAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.primary),
                ),
                if (!isReceived)
                  const Text('Pending Receipt', style: TextStyle(fontSize: 10, color: AppColors.warning)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'received': color = AppColors.success; break;
      case 'pending': color = AppColors.warning; break;
      case 'cancelled': color = AppColors.error; break;
      default: color = AppColors.grey500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
