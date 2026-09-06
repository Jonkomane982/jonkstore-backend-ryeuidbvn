import '../enums/inventory_transaction_type.dart';
import '../enums/sync_status.dart';

/// Records an immutable audit log of every stock change.
/// Aligned with the 008_inventory.sql schema and commercial requirements.
class InventoryTransaction {
  final String id;
  final String inventoryId;
  final String productId;
  final String branchId;
  final InventoryTransactionType type;
  final String? referenceId; // SaleId, PurchaseOrderId, or AdjustmentId
  final double quantityChange;
  final double previousQuantity;
  final double newQuantity;
  final double? unitCost; // Real landed cost at time of transaction
  final String? reason;
  final String? notes;
  final String userId;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  InventoryTransaction({
    required this.id,
    required this.inventoryId,
    required this.productId,
    required this.branchId,
    required this.type,
    this.referenceId,
    required this.quantityChange,
    required this.previousQuantity,
    required this.newQuantity,
    this.unitCost,
    this.reason,
    this.notes,
    required this.userId,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inventory_id': inventoryId,
      'product_id': productId,
      'branch_id': branchId,
      'transaction_type': type.name.toUpperCase(),
      'reference_id': referenceId,
      'quantity_change': quantityChange,
      'previous_quantity': previousQuantity,
      'new_quantity': newQuantity,
      'unit_cost': unitCost,
      'reason': reason,
      'notes': notes,
      'user_id': userId,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      id: json['id'] as String,
      inventoryId: json['inventory_id'] as String,
      productId: json['product_id'] as String,
      branchId: json['branch_id'] as String,
      type: InventoryTransactionType.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['transaction_type'] as String).toUpperCase(),
        orElse: () => InventoryTransactionType.adjustment,
      ),
      referenceId: json['reference_id'] as String?,
      quantityChange: (json['quantity_change'] as num).toDouble(),
      previousQuantity: (json['previous_quantity'] as num).toDouble(),
      newQuantity: (json['new_quantity'] as num).toDouble(),
      unitCost: json['unit_cost'] != null ? (json['unit_cost'] as num).toDouble() : null,
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      userId: json['user_id'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
