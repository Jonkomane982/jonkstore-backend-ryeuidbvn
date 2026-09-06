import '../enums/sync_status.dart';

/// Represents a batch of stock adjustments for auditing.
class InventoryAdjustment {
  final String id;
  final String branchId;
  final DateTime adjustmentDate;
  final String reasonCode; // DAMAGE, LOSS, CORRECTION, THEFT
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  InventoryAdjustment({
    required this.id,
    required this.branchId,
    required this.adjustmentDate,
    required this.reasonCode,
    this.notes,
    this.status = 'COMPLETED',
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'adjustment_date': adjustmentDate.toIso8601String(),
      'reason_code': reasonCode,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory InventoryAdjustment.fromJson(Map<String, dynamic> json) {
    return InventoryAdjustment(
      id: json['id'] as String,
      branchId: json['branch_id'] as String,
      adjustmentDate: DateTime.parse(json['adjustment_date'] as String),
      reasonCode: json['reason_code'] as String,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}
