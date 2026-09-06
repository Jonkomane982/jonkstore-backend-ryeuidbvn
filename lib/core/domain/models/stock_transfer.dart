import '../enums/sync_status.dart';

/// Represents the movement of stock between different business branches.
class StockTransfer {
  final String id;
  final String fromBranchId;
  final String toBranchId;
  final DateTime transferDate;
  final String status; // PENDING, SHIPPED, RECEIVED, CANCELLED
  final String? trackingNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  StockTransfer({
    required this.id,
    required this.fromBranchId,
    required this.toBranchId,
    required this.transferDate,
    this.status = 'PENDING',
    this.trackingNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_branch_id': fromBranchId,
      'to_branch_id': toBranchId,
      'transfer_date': transferDate.toIso8601String(),
      'status': status,
      'tracking_number': trackingNumber,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory StockTransfer.fromJson(Map<String, dynamic> json) {
    return StockTransfer(
      id: json['id'] as String,
      fromBranchId: json['from_branch_id'] as String,
      toBranchId: json['to_branch_id'] as String,
      transferDate: DateTime.parse(json['transfer_date'] as String),
      status: json['status'] as String,
      trackingNumber: json['tracking_number'] as String?,
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
