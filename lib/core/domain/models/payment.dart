import '../enums/payment_method.dart';
import '../enums/sync_status.dart';

/// Represents a financial transaction for a sale or other income.
class Payment {
  final String id;
  final String saleId;
  final double amount;
  final PaymentMethod method;
  final String? transactionReference; // e.g., M-Pesa code or Card Auth code
  final String status; // pending, completed, failed, refunded
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Payment({
    required this.id,
    required this.saleId,
    required this.amount,
    required this.method,
    this.transactionReference,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Payment copyWith({
    String? id,
    String? saleId,
    double? amount,
    PaymentMethod? method,
    String? transactionReference,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Payment(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      transactionReference: transactionReference ?? this.transactionReference,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'saleId': saleId,
      'amount': amount,
      'method': method.name,
      'transactionReference': transactionReference,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      saleId: json['saleId'],
      amount: (json['amount'] as num).toDouble(),
      method: PaymentMethod.values.firstWhere((e) => e.name == json['method']),
      transactionReference: json['transactionReference'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['syncStatus']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          saleId == other.saleId &&
          amount == other.amount &&
          method == other.method &&
          transactionReference == other.transactionReference &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      saleId.hashCode ^
      amount.hashCode ^
      method.hashCode ^
      transactionReference.hashCode ^
      status.hashCode;
}
