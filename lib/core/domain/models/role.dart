import '../enums/sync_status.dart';

/// Represents a set of permissions or a specific job title within the business.
class Role {
  final String id;
  final String name;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Role({
    required this.id,
    required this.name,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Role copyWith({
    String? id,
    String? name,
    List<String>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'permissions': permissions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
      permissions: List<String>.from(json['permissions']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['syncStatus']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          permissions == other.permissions &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          syncStatus == other.syncStatus;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      permissions.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      syncStatus.hashCode;
}
