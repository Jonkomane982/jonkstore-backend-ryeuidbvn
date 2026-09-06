import '../database_service.dart';
import '../database_constants.dart';

class CategorySalesData {
  final String categoryName;
  final double totalSales;
  CategorySalesData(this.categoryName, this.totalSales);
}

class ProductSalesData {
  final String productName;
  final double quantitySold;
  final double totalRevenue;
  ProductSalesData(this.productName, this.quantitySold, this.totalRevenue);
}

/// Data Access Object for generating complex business reports.
class ReportsDao {
  final DatabaseService _databaseService;

  ReportsDao(this._databaseService);

  /// Gets total sales aggregated by category for a specific date range.
  Future<List<CategorySalesData>> getSalesByCategory(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    final results = await db.rawQuery('''
      SELECT c.name as categoryName, SUM(si.totalAmount) as totalSales
      FROM ${DatabaseConstants.tableSaleItems} si
      JOIN ${DatabaseConstants.tableProducts} p ON si.productId = p.id
      JOIN categories c ON p.categoryId = c.id
      JOIN ${DatabaseConstants.tableSales} s ON si.saleId = s.id
      WHERE s.${DatabaseConstants.columnCreatedAt} BETWEEN ? AND ?
        AND s.status = 'completed'
      GROUP BY c.id
      ORDER BY totalSales DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return results.map((row) => CategorySalesData(
      row['categoryName'] as String,
      (row['totalSales'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  /// Gets the top selling products by quantity for a specific date range.
  Future<List<ProductSalesData>> getTopSellingProducts(DateTime start, DateTime end, {int limit = 10}) async {
    final db = await _databaseService.database;
    final results = await db.rawQuery('''
      SELECT si.productName, SUM(si.quantity) as quantitySold, SUM(si.totalAmount) as totalRevenue
      FROM ${DatabaseConstants.tableSaleItems} si
      JOIN ${DatabaseConstants.tableSales} s ON si.saleId = s.id
      WHERE s.${DatabaseConstants.columnCreatedAt} BETWEEN ? AND ?
        AND s.status = 'completed'
      GROUP BY si.productId
      ORDER BY quantitySold DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    return results.map((row) => ProductSalesData(
      row['productName'] as String,
      (row['quantitySold'] as num?)?.toDouble() ?? 0.0,
      (row['totalRevenue'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  /// Gets daily revenue for the last 30 days.
  Future<List<Map<String, dynamic>>> getDailyRevenue(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    return await db.rawQuery('''
      SELECT DATE(${DatabaseConstants.columnCreatedAt}) as date, SUM(totalAmount) as revenue
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.columnCreatedAt} BETWEEN ? AND ?
        AND status = 'completed'
      GROUP BY date
      ORDER BY date ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }
}
