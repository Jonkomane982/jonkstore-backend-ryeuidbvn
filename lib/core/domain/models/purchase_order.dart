import '../enums/sync_status.dart';

/// Represents a formal request to a supplier for products.
/// Aligned with the 007_purchases.sql schema.
class PurchaseOrder {
  final String id;
  final String supplierId;
  final String businessId;
  final String branchId;
  final String? orderNumber;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final DateTime? receivedDate;
  final String status; // draft, ordered, partial, received, cancelled
  final String paymentStatus; // unpaid, partial, paid
  final double subtotal;
  final double taxTotal;
  final double shippingCost;
  final double otherCosts; // Runner Fee
  final String allocationMethod; // PROPORTIONAL, EQUAL
  final double totalAmount; // Total Investment
  final double paidAmount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final int version;
  final String? createdBy;
  final String? updatedBy;

  // Extra fields for UI/Calculations joined from other tables
  final String? supplierName;

  PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.businessId,
    required this.branchId,
    this.orderNumber,
    required this.orderDate,
    this.expectedDate,
    this.receivedDate,
    required this.status,
    this.paymentStatus = 'unpaid',
    this.subtotal = 0,
    this.taxTotal = 0,
    this.shippingCost = 0,
    this.otherCosts = 0,
    this.allocationMethod = 'PROPORTIONAL',
    required this.totalAmount,
    this.paidAmount = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.version = 1,
    this.createdBy,
    this.updatedBy,
    this.supplierName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'branch_id': branchId,
      'supplier_id': supplierId,
      'order_number': orderNumber,
      'order_date': orderDate.toIso8601String(),
      'expected_delivery_date': expectedDate?.toIso8601String(),
      'received_date': receivedDate?.toIso8601String(),
      'status': status.toUpperCase(),
      'payment_status': paymentStatus.toUpperCase(),
      'subtotal': subtotal,
      'tax_total': taxTotal,
      'shipping_cost': shippingCost,
      'other_costs': otherCosts,
      'allocation_method': allocationMethod.toUpperCase(),
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name.toUpperCase(),
      'version': version,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'],
      businessId: json['business_id'] ?? json['businessId'] ?? '',
      branchId: json['branch_id'] ?? json['branchId'] ?? '',
      supplierId: json['supplier_id'] ?? json['supplierId'] ?? '',
      orderNumber: json['order_number'] ?? json['orderNumber'],
      orderDate: DateTime.parse(json['order_date'] ?? json['orderDate']),
      expectedDate: (json['expected_delivery_date'] ?? json['expectedDate']) != null 
          ? DateTime.parse(json['expected_delivery_date'] ?? json['expectedDate']) : null,
      receivedDate: json['received_date'] != null ? DateTime.parse(json['received_date']) : null,
      status: (json['status'] as String).toLowerCase(),
      paymentStatus: (json['payment_status'] as String? ?? 'unpaid').toLowerCase(),
      subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
      taxTotal: (json['tax_total'] as num? ?? 0).toDouble(),
      shippingCost: (json['shipping_cost'] as num? ?? 0).toDouble(),
      otherCosts: (json['other_costs'] as num? ?? 0).toDouble(),
      allocationMethod: json['allocation_method'] as String? ?? 'PROPORTIONAL',
      totalAmount: (json['total_amount'] as num? ?? json['totalAmount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] as num? ?? 0).toDouble(),
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['sync_status'] as String? ?? 'PENDING').toUpperCase(),
        orElse: () => SyncStatus.pending,
      ),
      version: json['version'] ?? 1,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      supplierName: json['supplier_name'],
    );
  }

  PurchaseOrder copyWith({
    String? status,
    String? paymentStatus,
    double? paidAmount,
    DateTime? receivedDate,
    DateTime? updatedAt,
    String? updatedBy,
    SyncStatus? syncStatus,
  }) {
    return PurchaseOrder(
      id: id,
      supplierId: supplierId,
      businessId: businessId,
      branchId: branchId,
      orderNumber: orderNumber,
      orderDate: orderDate,
      expectedDate: expectedDate,
      receivedDate: receivedDate ?? this.receivedDate,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subtotal: subtotal,
      taxTotal: taxTotal,
      shippingCost: shippingCost,
      otherCosts: otherCosts,
      allocationMethod: allocationMethod,
      totalAmount: totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      supplierName: supplierName,
    );
  }
}
