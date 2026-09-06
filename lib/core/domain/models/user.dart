import '../enums/sync_status.dart';
import '../enums/user_role.dart';

/// Represents a user account in the system.
class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profileImageUrl;
  final UserRole role;
  final String? businessId;
  final String? branchId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profileImageUrl,
    required this.role,
    this.businessId,
    this.branchId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profileImageUrl,
    UserRole? role,
    String? businessId,
    String? branchId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'role': role.name,
      'businessId': businessId,
      'branchId': branchId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      profileImageUrl: json['profileImageUrl'],
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      businessId: json['businessId'],
      branchId: json['branchId'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['syncStatus']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          email == other.email &&
          role == other.role &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ email.hashCode ^ role.hashCode ^ isActive.hashCode;
}
