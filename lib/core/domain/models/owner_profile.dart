import '../enums/sync_status.dart';
import '../enums/user_role.dart';

/// Represents the profile of the fixed application owner.
///
/// **Important**: businessId is REQUIRED (matches SQL schema: owner_profile.business_id TEXT NOT NULL).
/// An OwnerProfile MUST NOT be persisted until a valid Business record exists first.
class OwnerProfile {
  final String id;
  final String businessId;
  final String firebaseUid;
  final String username;
  final UserRole role;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final String? passwordHash;

  OwnerProfile({
    required this.id,
    required this.businessId,
    required this.firebaseUid,
    required this.username,
    this.role = UserRole.owner,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
    this.passwordHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'firebase_uid': firebaseUid,
      'username': username,
      'role': role.name,
      'is_verified': isVerified ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
      'password_hash': passwordHash,
    };
  }

  factory OwnerProfile.fromJson(Map<String, dynamic> json) {
    return OwnerProfile(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      firebaseUid: json['firebase_uid'] as String,
      username: json['username'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.owner,
      ),
      isVerified: json['is_verified'] == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
      passwordHash: json['password_hash'] as String?,
    );
  }

  OwnerProfile copyWith({
    String? businessId,
    String? username,
    bool? isVerified,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
    String? passwordHash,
  }) {
    return OwnerProfile(
      id: id,
      businessId: businessId ?? this.businessId,
      firebaseUid: firebaseUid,
      username: username ?? this.username,
      role: role,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}
