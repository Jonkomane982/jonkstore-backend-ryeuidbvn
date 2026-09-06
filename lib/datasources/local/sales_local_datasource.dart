import '../../database/database_service.dart';
import '../../core/domain/models/sale.dart';
import '../../core/domain/models/sale_item.dart';
import '../../database/database_constants.dart';

/// Local data source for Sales operations using SQLite.
class SalesLocalDataSource {
  final DatabaseService _databaseService;

  SalesLocalDataSource(this._databaseService);

  Future<void> insertSale(Sale sale, List<SaleItem> items) async {
    await _databaseService.transaction((txn) async {
      await txn.insert(DatabaseConstants.tableSales, sale.toJson());
      for (final item in items) {
        await txn.insert(DatabaseConstants.tableSaleItems, item.toJson());
      }
    });
  }

  Future<Sale?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSales,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? Sale.fromJson(results.first) : null;
  }

  Future<List<SaleItem>> getSaleItems(String saleId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSaleItems,
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
    return results.map((e) => SaleItem.fromJson(e)).toList();
  }

  Future<List<Sale>> findAll() async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSales, 
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC'
    );
    return results.map((e) => Sale.fromJson(e)).toList();
  }

  Future<List<Sale>> findByDateRange(DateTime start, DateTime end) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSales,
      where: '${DatabaseConstants.columnCreatedAt} BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
    );
    return results.map((e) => Sale.fromJson(e)).toList();
  }
}
