import '../enums/sync_status.dart';
import '../enums/payment_method.dart';

/// Represents a completed transaction where products are sold to a customer.
class Sale {
  final String id;
  final String? customerId;
  final String businessId;
  final String branchId;
  final String userId;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final double receivedAmount;
  final double changeAmount;
  final PaymentMethod paymentMethod;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Sale({
    required this.id,
    this.customerId,
    required this.businessId,
    required this.branchId,
    required this.userId,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.receivedAmount,
    required this.changeAmount,
    required this.paymentMethod,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'businessId': businessId,
      'branchId': branchId,
      'userId': userId,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'receivedAmount': receivedAmount,
      'changeAmount': changeAmount,
      'paymentMethod': paymentMethod.name,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      customerId: json['customerId'],
      businessId: json['businessId'],
      branchId: json['branchId'],
      userId: json['userId'],
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      receivedAmount: (json['receivedAmount'] as num).toDouble(),
      changeAmount: (json['changeAmount'] as num).toDouble(),
      paymentMethod: PaymentMethod.values.firstWhere((e) => e.name == json['paymentMethod']),
      status: json['status'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['sync_status']),
    );
  }
}
