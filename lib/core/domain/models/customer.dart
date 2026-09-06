import '../enums/sync_status.dart';

/// Represents a customer of the business.
/// Aligned with 009_customers.sql schema.
class Customer {
  final String id;
  final String business_id;
  final String first_name;
  final String? last_name;
  final String? email;
  final String? phone;
  final String? address;
  final String? tax_id;
  final String customer_type; // INDIVIDUAL, CORPORATE
  final bool is_active;
  final double loyalty_points;
  final String? notes;
  final DateTime created_at;
  final DateTime updated_at;
  final SyncStatus sync_status;

  Customer({
    required this.id,
    required this.business_id,
    required this.first_name,
    this.last_name,
    this.email,
    this.phone,
    this.address,
    this.tax_id,
    this.customer_type = 'INDIVIDUAL',
    this.is_active = true,
    this.loyalty_points = 0.0,
    this.notes,
    required this.created_at,
    required this.updated_at,
    this.sync_status = SyncStatus.pending,
  });

  /// Compatibility getter for UI
  String get name => '$first_name ${last_name ?? ''}'.trim();
  String get fullName => name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': business_id,
      'first_name': first_name,
      'last_name': last_name,
      'email': email,
      'phone': phone,
      'address': address,
      'tax_id': tax_id,
      'customer_type': customer_type,
      'is_active': is_active ? 1 : 0,
      'loyalty_points': loyalty_points,
      'notes': notes,
      'created_at': created_at.toIso8601String(),
      'updated_at': updated_at.toIso8601String(),
      'sync_status': sync_status.name,
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      business_id: json['business_id'] as String,
      first_name: json['first_name'] as String,
      last_name: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      tax_id: json['tax_id'] as String?,
      customer_type: json['customer_type'] as String? ?? 'INDIVIDUAL',
      is_active: (json['is_active'] ?? 1) == 1,
      loyalty_points: (json['loyalty_points'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      created_at: DateTime.parse(json['created_at'] as String),
      updated_at: DateTime.parse(json['updated_at'] as String),
      sync_status: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }

  Customer copyWith({
    String? first_name,
    String? last_name,
    String? email,
    String? phone,
    String? address,
    String? tax_id,
    String? customer_type,
    bool? is_active,
    double? loyalty_points,
    String? notes,
    DateTime? updated_at,
    SyncStatus? sync_status,
  }) {
    return Customer(
      id: id,
      business_id: business_id,
      first_name: first_name ?? this.first_name,
      last_name: last_name ?? this.last_name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      tax_id: tax_id ?? this.tax_id,
      customer_type: customer_type ?? this.customer_type,
      is_active: is_active ?? this.is_active,
      loyalty_points: loyalty_points ?? this.loyalty_points,
      notes: notes ?? this.notes,
      created_at: created_at,
      updated_at: updated_at ?? this.updated_at,
      sync_status: sync_status ?? this.sync_status,
    );
  }
}
