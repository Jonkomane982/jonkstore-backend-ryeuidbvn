import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jonkstore/app/theme/app_colors.dart';
import 'package:jonkstore/app/theme/app_spacing.dart';
import 'package:jonkstore/app/theme/app_text_styles.dart';
import 'package:jonkstore/core/auth/app_permission.dart';
import 'package:jonkstore/core/domain/models/purchase_order.dart';
import 'package:jonkstore/core/domain/models/purchase_order_item.dart';
import 'package:jonkstore/shared/loading/loading_indicator.dart';
import 'package:jonkstore/shared/buttons/primary_button.dart';
import 'package:jonkstore/shared/snackbars/custom_snack_bar.dart';
import 'package:jonkstore/shared/guards/permission_guard.dart';
import 'package:jonkstore/providers/repository_providers.dart';

class PurchaseOrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const PurchaseOrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<PurchaseOrderDetailsScreen> createState() => _PurchaseOrderDetailsScreenState();
}

class _PurchaseOrderDetailsScreenState extends ConsumerState<PurchaseOrderDetailsScreen> {
  PurchaseOrder? _order;
  List<PurchaseOrderItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    final repo = ref.read(purchaseRepositoryProvider);
    final orderResult = await repo.findById(widget.orderId);
    
    orderResult.fold(
      (order) async {
        if (order != null) {
          final itemsResult = await repo.getOrderItems(widget.orderId);
          itemsResult.fold(
            (items) => setState(() {
              _order = order;
              _items = items;
              _isLoading = false;
            }),
            (failure) => _handleError(failure.message),
          );
        } else {
          _handleError('Order not found');
        }
      },
      (failure) => _handleError(failure.message),
    );
  }

  void _handleError(String message) {
    setState(() => _isLoading = false);
    CustomSnackBar.showError(context, message);
  }

  Future<void> _receiveAll() async {
    setState(() => _isLoading = true);
    // Filter items that aren't fully received yet
    final pendingItems = _items.where((i) => i.receivedQuantity < i.quantity).toList();
    if (pendingItems.isEmpty) {
       CustomSnackBar.showInfo(context, 'All items already received');
       setState(() => _isLoading = false);
       return;
    }

    final toReceive = pendingItems.map((i) => i.copyWith(
      quantity: i.quantity - i.receivedQuantity,
    )).toList();

    final result = await ref.read(purchaseRepositoryProvider).receiveStock(
      orderId: widget.orderId,
      receivedItems: toReceive,
      isFinal: true,
    );
    
    result.fold(
      (_) async {
        await _loadOrderDetails();
        if (mounted) {
          CustomSnackBar.showSuccess(context, 'All items received successfully');
        }
      },
      (failure) => _handleError(failure.message),
    );
  }

  void _showPartialReceiptDialog() {
    showDialog(
      context: context,
      builder: (context) => _PartialReceiptDialog(
        items: _items.where((i) => i.receivedQuantity < i.quantity).toList(),
        onConfirm: (receivedItems, isFinal) async {
          setState(() => _isLoading = true);
          final result = await ref.read(purchaseRepositoryProvider).receiveStock(
            orderId: widget.orderId,
            receivedItems: receivedItems,
            isFinal: isFinal,
          );
          result.fold(
            (_) async {
              await _loadOrderDetails();
              if (mounted) CustomSnackBar.showSuccess(context, 'Stock updated');
            },
            (failure) => _handleError(failure.message),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: AppLoadingIndicator()));
    if (_order == null) return const Scaffold(body: Center(child: Text('Order not found')));

    final isReceivable = _order!.status != 'received' && _order!.status != 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: Text(_order!.orderNumber ?? 'Purchase Order'),
        actions: [
          if (_order!.status == 'ordered')
            PermissionGuard(
              permission: AppPermission.managePurchases,
              child: IconButton(
                icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                onPressed: () => _showCancelDialog(),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBanner(),
            const SizedBox(height: AppSpacing.lg),
            _buildSummaryCard(),
            const SizedBox(height: AppSpacing.xl),
            Text('Items in this Order', style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            _buildItemsList(),
            const SizedBox(height: AppSpacing.xxl),
            if (isReceivable) ...[
              PermissionGuard(
                permission: AppPermission.managePurchases,
                child: Column(
                  children: [
                    PrimaryButton(
                      text: 'Receive All Items',
                      icon: Icons.done_all,
                      onPressed: _receiveAll,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _showPartialReceiptDialog,
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('Record Partial Receipt'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color color;
    IconData icon;
    switch (_order!.status.toLowerCase()) {
      case 'received': color = AppColors.success; icon = Icons.verified; break;
      case 'partial': color = AppColors.warning; icon = Icons.pending_actions; break;
      case 'cancelled': color = AppColors.error; icon = Icons.cancel; break;
      default: color = AppColors.primary; icon = Icons.local_shipping;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${_order!.status.toUpperCase()}',
                style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                'Ordered on ${DateFormat('dd MMM yyyy').format(_order!.orderDate)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _InfoRow(label: 'Supplier', value: _order!.supplierName ?? 'N/A'),
            _InfoRow(label: 'Subtotal', value: 'KES ${_order!.subtotal.toStringAsFixed(2)}'),
            _InfoRow(label: 'Runner Fee', value: 'KES ${_order!.otherCosts.toStringAsFixed(2)}'),
            const Divider(),
            _InfoRow(
              label: 'Total Investment',
              value: 'KES ${_order!.totalAmount.toStringAsFixed(2)}',
              valueColor: AppColors.primary,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final landedUnit = _order!.subtotal > 0 
            ? (item.totalCost + (item.totalCost / _order!.subtotal * _order!.otherCosts)) / item.quantity
            : item.unitCost;
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName ?? 'Unknown Product', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item.quantity.toStringAsFixed(0)} units @ KES ${item.unitCost.toStringAsFixed(2)}', style: AppTextStyles.caption),
                    Text('Total: KES ${item.totalCost.toStringAsFixed(2)}', style: AppTextStyles.body.copyWith(fontSize: 12)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ItemMiniInfo(label: 'Received', value: '${item.receivedQuantity.toStringAsFixed(0)} / ${item.quantity.toStringAsFixed(0)}', 
                        valueColor: item.receivedQuantity == item.quantity ? AppColors.success : AppColors.warning),
                    _ItemMiniInfo(label: 'Landed Cost', value: 'KES ${landedUnit.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              await ref.read(purchaseRepositoryProvider).updateStatus(widget.orderId, 'cancelled');
              await _loadOrderDetails();
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _PartialReceiptDialog extends StatefulWidget {
  final List<PurchaseOrderItem> items;
  final Function(List<PurchaseOrderItem>, bool) onConfirm;

  const _PartialReceiptDialog({required this.items, required this.onConfirm});

  @override
  State<_PartialReceiptDialog> createState() => _PartialReceiptDialogState();
}

class _PartialReceiptDialogState extends State<_PartialReceiptDialog> {
  final Map<String, double> _receivedQtys = {};
  bool _isFinal = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.items) {
      _receivedQtys[item.id] = item.quantity - item.receivedQuantity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Partial Stock Receipt'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(child: Text(item.productName ?? 'Item', style: const TextStyle(fontSize: 12))),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: (item.quantity - item.receivedQuantity).toStringAsFixed(0),
                          labelText: 'Qty',
                        ),
                        onChanged: (val) {
                          _receivedQtys[item.id] = double.tryParse(val) ?? 0;
                        },
                      ),
                    ),
                  ],
                ),
              )),
              CheckboxListTile(
                title: const Text('Mark as fully received', style: TextStyle(fontSize: 12)),
                value: _isFinal,
                onChanged: (val) => setState(() => _isFinal = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final toReceive = widget.items.map((i) => i.copyWith(
              quantity: _receivedQtys[i.id] ?? 0,
            )).where((i) => i.quantity > 0).toList();
            
            if (toReceive.isNotEmpty) {
              Navigator.pop(context);
              widget.onConfirm(toReceive, _isFinal);
            }
          },
          child: const Text('Confirm Receipt'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InfoRow({required this.label, required this.value, this.valueColor, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body.copyWith(color: AppColors.grey600)),
          Text(value, style: AppTextStyles.body.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

class _ItemMiniInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _ItemMiniInfo({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }
}
