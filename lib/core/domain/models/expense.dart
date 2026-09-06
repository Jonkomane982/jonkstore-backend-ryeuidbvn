import '../enums/sync_status.dart';
import '../enums/payment_method.dart';

/// Represents a business expense or outgoing payment.
class Expense {
  final String id;
  final String businessId;
  final String branchId;
  final String category; // Rent, Utilities, Salary, etc.
  final double amount;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? description;
  final String? attachmentUrl; // Receipt image
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Expense({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.category,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.description,
    this.attachmentUrl,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'branchId': branchId,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod.name,
      'description': description,
      'attachmentUrl': attachmentUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      businessId: json['businessId'],
      branchId: json['branchId'],
      category: json['category'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      paymentMethod: PaymentMethod.values.firstWhere((e) => e.name == json['paymentMethod']),
      description: json['description'],
      attachmentUrl: json['attachmentUrl'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
