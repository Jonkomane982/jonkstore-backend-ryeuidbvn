import '../enums/sync_status.dart';

/// Represents a product category.
/// Aligned with the commercial 3NF schema for synchronization and auditing.
class Category {
  final String id;
  final String name;
  final String? description;
  final String? businessId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isDeleted;
  final SyncStatus syncStatus;
  final int version;
  final String? createdBy;
  final String? updatedBy;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.businessId,
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

  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? businessId,
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
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      businessId: businessId ?? this.businessId,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'business_id': businessId,
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

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      businessId: json['business_id'],
      isActive: (json['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      isDeleted: (json['is_deleted'] ?? 0) == 1,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
      version: json['version'] ?? 1,
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
    );
  }
}
