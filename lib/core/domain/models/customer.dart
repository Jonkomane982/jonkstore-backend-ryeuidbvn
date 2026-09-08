import '../enums/sync_status.dart';

/// Represents a customer of the business.
class Customer {
  final String id;
  final String businessId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? address;
  final String? taxId;
  final String customerType; // INDIVIDUAL, CORPORATE
  final bool isActive;
  final double loyaltyPoints;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Customer({
    required this.id,
    required this.businessId,
    required this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.address,
    this.taxId,
    this.customerType = 'INDIVIDUAL',
    this.isActive = true,
    this.loyaltyPoints = 0.0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  String get name => '$firstName ${lastName ?? ''}'.trim();
  String get fullName => name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'address': address,
      'tax_id': taxId,
      'customer_type': customerType,
      'is_active': isActive ? 1 : 0,
      'loyalty_points': loyaltyPoints,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      taxId: json['tax_id'] as String?,
      customerType: json['customer_type'] as String? ?? 'INDIVIDUAL',
      isActive: (json['is_active'] ?? 1) == 1,
      loyaltyPoints: (json['loyalty_points'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
