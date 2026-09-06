import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/inventory_count.dart';

/// Data Access Object for physical stock count sessions.
class InventoryCountDao {
  final DatabaseService _databaseService;

  InventoryCountDao(this._databaseService);

  Future<void> insert(InventoryCount count, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(
      DatabaseConstants.tableInventoryCounts,
      count.toJson(),
    );
  }

  Future<InventoryCount?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventoryCounts,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? InventoryCount.fromJson(results.first) : null;
  }

  Future<List<InventoryCount>> findAll(String branchId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableInventoryCounts,
      where: '${DatabaseConstants.columnBranchId} = ?',
      whereArgs: [branchId],
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
    );
    return results.map((e) => InventoryCount.fromJson(e)).toList();
  }
}
