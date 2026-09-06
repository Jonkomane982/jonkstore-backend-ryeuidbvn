import '../enums/sync_status.dart';

/// Represents the stock level of a product at a specific branch.
/// Production-grade model aligned with 3NF schema.
class Inventory {
  final String id;
  final String productId;
  final String? variantId;
  final String branchId;
  final double quantity;
  final double reservedQuantity;
  final double lowStockThreshold;
  final double reorderLevel;
  final String? binLocation;
  final DateTime? lastCountDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Inventory({
    required this.id,
    required this.productId,
    this.variantId,
    required this.branchId,
    required this.quantity,
    this.reservedQuantity = 0.0,
    this.lowStockThreshold = 10.0,
    this.reorderLevel = 5.0,
    this.binLocation,
    this.lastCountDate,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Inventory copyWith({
    double? quantity,
    double? reservedQuantity,
    double? lowStockThreshold,
    double? reorderLevel,
    String? binLocation,
    DateTime? lastCountDate,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Inventory(
      id: id,
      productId: productId,
      variantId: variantId,
      branchId: branchId,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      binLocation: binLocation ?? this.binLocation,
      lastCountDate: lastCountDate ?? this.lastCountDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'variant_id': variantId,
      'branch_id': branchId,
      'quantity': quantity,
      'reserved_quantity': reservedQuantity,
      'low_stock_threshold': lowStockThreshold,
      'reorder_level': reorderLevel,
      'bin_location': binLocation,
      'last_count_date': lastCountDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Inventory.fromJson(Map<String, dynamic> json) {
    return Inventory(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      branchId: json['branch_id'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      reservedQuantity: (json['reserved_quantity'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toDouble() ?? 10.0,
      reorderLevel: (json['reorder_level'] as num?)?.toDouble() ?? 5.0,
      binLocation: json['bin_location'] as String?,
      lastCountDate: json['last_count_date'] != null 
          ? DateTime.parse(json['last_count_date'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
