import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/dashboard_summary.dart';
import '../../core/domain/enums/sync_status.dart';

/// Data Access Object for Dashboard-related aggregation queries.
class DashboardDao {
  final DatabaseService _databaseService;

  DashboardDao(this._databaseService);

  static T? _firstOrNull<T>(List<Map<String, Object?>> rows, String key) {
    if (rows.isEmpty) return null;
    final row = rows.first;
    return row[key] as T?;
  }

  /// Calculates a summary of business performance for a specific date range.
  Future<DashboardSummary> getSummary(
    DateTime start,
    DateTime end,
    String period,
  ) async {
    final db = await _databaseService.database;

    // 1. Calculate Total Revenue and Sales Count
    final salesResult = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as count, 
        SUM(totalAmount) as revenue 
      FROM ${DatabaseConstants.tableSales} 
      WHERE ${DatabaseConstants.columnCreatedAt} BETWEEN ? AND ? 
        AND status = 'completed'
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final salesCount = (_firstOrNull<int>(salesResult, 'count')) ?? 0;
    final totalRevenue =
        (_firstOrNull<num>(salesResult, 'revenue'))?.toDouble() ?? 0.0;

    // 2. Calculate Total Profit
    // Profit = Total Revenue - Total Cost of items sold
    final profitResult = await db.rawQuery(
      '''
      SELECT SUM(si.quantity * (si.unitPrice - p.costPrice)) as profit
      FROM ${DatabaseConstants.tableSaleItems} si
      JOIN ${DatabaseConstants.tableProducts} p ON si.productId = p.id
      JOIN ${DatabaseConstants.tableSales} s ON si.saleId = s.id
      WHERE s.${DatabaseConstants.columnCreatedAt} BETWEEN ? AND ? 
        AND s.status = 'completed'
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final totalProfit =
        (_firstOrNull<num>(profitResult, 'profit'))?.toDouble() ?? 0.0;

    // 3. Get Total Customers
    final customersResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableCustomers}',
    );
    final totalCustomers = (_firstOrNull<int>(customersResult, 'count')) ?? 0;

    // 4. Get Low Stock Count
    final lowStockResult = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM ${DatabaseConstants.tableInventory} 
      WHERE quantity <= lowStockThreshold
    ''');
    final lowStockCount = (_firstOrNull<int>(lowStockResult, 'count')) ?? 0;

    // 5. Get Total Expenses
    final expensesResult = await db.rawQuery(
      '''
      SELECT SUM(amount) as total 
      FROM ${DatabaseConstants.tableExpenses} 
      WHERE date BETWEEN ? AND ?
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    final totalExpenses =
        (_firstOrNull<num>(expensesResult, 'total'))?.toDouble() ?? 0.0;

    final avgOrderValue = salesCount > 0 ? totalRevenue / salesCount : 0.0;

    return DashboardSummary(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      totalRevenue: totalRevenue,
      totalProfit: totalProfit,
      totalSalesCount: salesCount,
      averageOrderValue: avgOrderValue,
      totalExpenses: totalExpenses,
      totalCustomers: totalCustomers,
      lowStockCount: lowStockCount,
      period: period,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
    );
  }
}
