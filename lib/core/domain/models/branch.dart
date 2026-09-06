import '../enums/sync_status.dart';

/// Represents a physical branch or location of a business.
class Branch {
  final String id;
  final String businessId;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Branch({
    required this.id,
    required this.businessId,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessId': businessId,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'isActive': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      businessId: json['businessId'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      isActive: json['isActive'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
