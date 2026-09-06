import '../enums/sync_status.dart';

/// Represents a vendor or supplier who provides products to the business.
///
/// Field names are strictly aligned with the commercial-grade 3NF SQLite
/// schema as defined in `005_suppliers.sql`.  All soft-delete, audit,
/// and sync metadata columns are present so the record survives the
/// complete offline-first lifecycle.
class Supplier {
  final String id;
  final String? businessId;

  final String name;
  final String code;
  final String? taxId;
  final String? website;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? contactName;
  final String? paymentTerms;
  final double creditLimit;
  final double currentBalance;
  final String? notes;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;

  final SyncStatus syncStatus;
  final int version;
  final String? createdBy;
  final String? updatedBy;

  Supplier({
    required this.id,
    this.businessId,
    required this.name,
    required this.code,
    this.taxId,
    this.website,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.contactName,
    this.paymentTerms,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.syncStatus = SyncStatus.pending,
    this.version = 1,
    this.createdBy,
    this.updatedBy,
  });

  Supplier copyWith({
    String? id,
    String? businessId,
    String? name,
    String? code,
    String? taxId,
    String? website,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? contactName,
    String? paymentTerms,
    double? creditLimit,
    double? currentBalance,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
    int? version,
    String? createdBy,
    String? updatedBy,
  }) {
    return Supplier(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      code: code ?? this.code,
      taxId: taxId ?? this.taxId,
      website: website ?? this.website,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      contactName: contactName ?? this.contactName,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Matches the exact snake_case column names used by the approved SQLite
  /// schema in `005_suppliers.sql`.  These keys are consumed verbatim by
  /// `SupplierDao.insert()` / `update()` and the SyncEngine serialiser.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'code': code,
      'tax_id': taxId,
      'website': website,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'contactName': contactName,
      'payment_terms': paymentTerms,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'sync_status': syncStatus.name.toUpperCase(),
      'version': version,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  factory Supplier.fromJson(Map<String, dynamic> json) {
    T? cast<T>(Object? v) => v is T ? v : null;
    double asDouble(Object? v, [double fallback = 0]) {
      if (v == null) return fallback;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      final s = v.toString();
      return double.tryParse(s) ?? fallback;
    }

    return Supplier(
      id: json['id'] as String,
      businessId: cast<String>(json['business_id']),
      name: json['name'] as String,
      code: (json['code'] as String?) ?? '',
      taxId: cast<String>(json['tax_id']),
      website: cast<String>(json['website']),
      email: cast<String>(json['email']),
      phone: cast<String>(json['phone']),
      address: cast<String>(json['address']),
      city: cast<String>(json['city']),
      state: cast<String>(json['state']),
      country: cast<String>(json['country']),
      postalCode: cast<String>(json['postal_code']),
      contactName: cast<String>(json['contactName']),
      paymentTerms: cast<String>(json['payment_terms']),
      creditLimit: asDouble(json['credit_limit']),
      currentBalance: asDouble(json['current_balance']),
      notes: cast<String>(json['notes']),
      isActive: (json['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      isDeleted: (json['is_deleted'] as int? ?? 0) == 1,
      syncStatus: SyncStatus.values.firstWhere(
        (e) =>
            e.name.toUpperCase() ==
            (json['sync_status'] as String? ?? 'PENDING'),
        orElse: () => SyncStatus.pending,
      ),
      version: (json['version'] as int?) ?? 1,
      createdBy: cast<String>(json['created_by']),
      updatedBy: cast<String>(json['updated_by']),
    );
  }
}
