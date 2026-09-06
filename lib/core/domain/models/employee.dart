import '../enums/sync_status.dart';

/// Represents an employee record within a business or branch.
class Employee {
  final String id;
  final String userId;
  final String businessId;
  final String branchId;
  final String employeeCode;
  final String designation;
  final double? salary;
  final DateTime? joiningDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  Employee({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.branchId,
    required this.employeeCode,
    required this.designation,
    this.salary,
    this.joiningDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'businessId': businessId,
      'branchId': branchId,
      'employeeCode': employeeCode,
      'designation': designation,
      'salary': salary,
      'joiningDate': joiningDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      userId: json['userId'],
      businessId: json['businessId'],
      branchId: json['branchId'],
      employeeCode: json['employeeCode'],
      designation: json['designation'],
      salary: json['salary'] != null ? (json['salary'] as num).toDouble() : null,
      joiningDate: json['joiningDate'] != null ? DateTime.parse(json['joiningDate']) : null,
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
