import '../enums/sync_status.dart';

/// Represents a stock count session for a branch.
class InventoryCount {
  final String id;
  final String branchId;
  final DateTime countDate;
  final String status; // IN_PROGRESS, RECONCILED, CLOSED
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  InventoryCount({
    required this.id,
    required this.branchId,
    required this.countDate,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'count_date': countDate.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory InventoryCount.fromJson(Map<String, dynamic> json) {
    return InventoryCount(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      countDate: DateTime.parse(json['count_date'] as String),
      status: json['status'] as String,
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
