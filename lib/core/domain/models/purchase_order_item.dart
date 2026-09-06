import '../enums/sync_status.dart';

/// Represents an individual item within a purchase order.
class PurchaseOrderItem {
  final String id;
  final String purchaseOrderId;
  final String productId;
  final String? variantId;
  final String? sku;
  final double quantity;
  final double receivedQuantity;
  final double unitCost;
  final double taxRate;
  final double taxAmount;
  final double discountRate;
  final double discountAmount;
  final double totalCost;
  final double allocatedRunnerFee; // From runner_fee_allocations table
  final DateTime? expiryDate;
  final String? batchNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final int version;
  final String? createdBy;
  final String? updatedBy;

  // UI Helper fields (joined from Product)
  final String? productName;
  final String? productBarcode;

  PurchaseOrderItem({
    required this.id,
    required this.purchaseOrderId,
    required this.productId,
    this.variantId,
    this.sku,
    required this.quantity,
    this.receivedQuantity = 0,
    required this.unitCost,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.discountRate = 0,
    this.discountAmount = 0,
    required this.totalCost,
    this.allocatedRunnerFee = 0,
    this.expiryDate,
    this.batchNumber,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.version = 1,
    this.createdBy,
    this.updatedBy,
    this.productName,
    this.productBarcode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_order_id': purchaseOrderId,
      'product_id': productId,
      'variant_id': variantId,
      'sku': sku,
      'quantity': quantity,
      'received_quantity': receivedQuantity,
      'unit_cost': unitCost,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'discount_rate': discountRate,
      'discount_amount': discountAmount,
      'total_cost': totalCost,
      'runner_fee_allocation': allocatedRunnerFee,
      'expiry_date': expiryDate?.toIso8601String(),
      'batch_number': batchNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name.toUpperCase(),
      'version': version,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'],
      purchaseOrderId: json['purchase_order_id'] ?? json['purchaseOrderId'] ?? '',
      productId: json['product_id'] ?? json['productId'] ?? '',
      variantId: json['variant_id'] ?? json['variantId'],
      sku: json['sku'],
      quantity: (json['quantity'] as num).toDouble(),
      receivedQuantity: (json['received_quantity'] as num? ?? 0).toDouble(),
      unitCost: (json['unit_cost'] as num? ?? json['unitCost'] ?? 0).toDouble(),
      taxRate: (json['tax_rate'] as num? ?? 0).toDouble(),
      taxAmount: (json['tax_amount'] as num? ?? 0).toDouble(),
      discountRate: (json['discount_rate'] as num? ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] as num? ?? 0).toDouble(),
      totalCost: (json['total_cost'] as num? ?? json['totalCost'] ?? 0).toDouble(),
      allocatedRunnerFee: (json['runner_fee_allocation'] as num? ?? json['allocatedRunnerFee'] ?? 0).toDouble(),
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']) : null,
      batchNumber: json['batch_number'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['sync_status'] as String? ?? 'PENDING').toUpperCase(),
        orElse: () => SyncStatus.pending,
      ),
      version: json['version'] ?? 1,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      productName: json['product_name'],
      productBarcode: json['barcode'],
    );
  }

  PurchaseOrderItem copyWith({
    double? quantity,
    double? receivedQuantity,
    double? unitCost,
    double? totalCost,
    double? allocatedRunnerFee,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return PurchaseOrderItem(
      id: id,
      purchaseOrderId: purchaseOrderId,
      productId: productId,
      variantId: variantId,
      sku: sku,
      quantity: quantity ?? this.quantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      unitCost: unitCost ?? this.unitCost,
      taxRate: taxRate,
      taxAmount: taxAmount,
      discountRate: discountRate,
      discountAmount: discountAmount,
      totalCost: totalCost ?? this.totalCost,
      allocatedRunnerFee: allocatedRunnerFee ?? this.allocatedRunnerFee,
      expiryDate: expiryDate,
      batchNumber: batchNumber,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus,
      version: version,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      productName: productName,
      productBarcode: productBarcode,
    );
  }
}
