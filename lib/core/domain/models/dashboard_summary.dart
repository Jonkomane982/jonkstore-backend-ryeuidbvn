import '../enums/sync_status.dart';

/// Represents a high-level summary of business performance for the dashboard.
class DashboardSummary {
  final String id;
  final double totalRevenue;
  final double totalProfit;
  final int totalSalesCount;
  final double averageOrderValue;
  final double totalExpenses;
  final int totalCustomers;
  final int lowStockCount;
  final String period;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  DashboardSummary({
    required this.id,
    required this.totalRevenue,
    required this.totalProfit,
    required this.totalSalesCount,
    required this.averageOrderValue,
    required this.totalExpenses,
    required this.totalCustomers,
    required this.lowStockCount,
    required this.period,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.synced,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'totalRevenue': totalRevenue,
      'totalProfit': totalProfit,
      'totalSalesCount': totalSalesCount,
      'averageOrderValue': averageOrderValue,
      'totalExpenses': totalExpenses,
      'totalCustomers': totalCustomers,
      'lowStockCount': lowStockCount,
      'period': period,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus.name,
    };
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      id: json['id'],
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      totalProfit: (json['totalProfit'] as num).toDouble(),
      totalSalesCount: json['totalSalesCount'] as int,
      averageOrderValue: (json['averageOrderValue'] as num).toDouble(),
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      totalCustomers: json['totalCustomers'] as int,
      lowStockCount: json['lowStockCount'] as int,
      period: json['period'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncStatus: SyncStatus.values.firstWhere((e) => e.name == json['sync_status']),
    );
  }
}
