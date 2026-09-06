import '../enums/sync_status.dart';

/// Represents a business entity in the JonkStore POS.
///
/// Aligned with SQL schema (002_business.sql / schema_scripts.dart):
/// - currencyId is REQUIRED (FK → currencies.id). Seed currency KES = CUR001.
/// - Non-persisted convenience fields (currency code, address, receiptFooter, etc.)
///   are stored separately (business_settings) but kept on the model for UI convenience.
class Business {
  final String id;
  final String name;
  final String? taxId;
  final String? registrationNumber;
  final String? email;
  final String? phone;
  final String? website;
  final String? logoUrl;
  final String currencyId;
  final String baseTimezone;
  final bool isActive;

  // ---- Non-persisted UI convenience fields ----
  final String? address;
  final String? country;
  final String? currency;
  final String? businessType;
  final String? receiptFooter;

  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Business({
    required this.id,
    required this.name,
    this.taxId,
    this.registrationNumber,
    this.email,
    this.phone,
    this.website,
    this.logoUrl,
    required this.currencyId,
    this.baseTimezone = 'UTC',
    this.isActive = true,
    this.address,
    this.country,
    this.currency,
    this.businessType,
    this.receiptFooter,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Business copyWith({
    String? id,
    String? name,
    String? taxId,
    String? registrationNumber,
    String? email,
    String? phone,
    String? website,
    String? logoUrl,
    String? currencyId,
    String? baseTimezone,
    bool? isActive,
    String? address,
    String? country,
    String? currency,
    String? businessType,
    String? receiptFooter,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      taxId: taxId ?? this.taxId,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
      currencyId: currencyId ?? this.currencyId,
      baseTimezone: baseTimezone ?? this.baseTimezone,
      isActive: isActive ?? this.isActive,
      address: address ?? this.address,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      businessType: businessType ?? this.businessType,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Produces a map compatible with the `businesses` SQL table columns.
  /// Non-persisted helper fields are excluded.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tax_id': taxId,
      'registration_number': registrationNumber,
      'email': email,
      'phone': phone,
      'website': website,
      'logo_url': logoUrl,
      'currency_id': currencyId,
      'base_timezone': baseTimezone,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  /// Reads from the `businesses` SQL table. Extra UI fields are populated from
  /// business_settings by the repository layer; they remain null here if the
  /// join is not performed.
  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as String,
      name: json['name'] as String,
      taxId: json['tax_id'] as String?,
      registrationNumber: json['registration_number'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      logoUrl: json['logo_url'] as String?,
      currencyId: json['currency_id'] as String,
      baseTimezone: (json['base_timezone'] as String?) ?? 'UTC',
      isActive: (json['is_active'] as int?) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == (json['sync_status'] as String?),
        orElse: () => SyncStatus.pending,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Business &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          phone == other.phone;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      email.hashCode ^
      phone.hashCode;
}
