import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';

/// Data Access Object for manual inventory adjustments.
class InventoryAdjustmentDao {
  final DatabaseService _databaseService;

  InventoryAdjustmentDao(this._databaseService);

  Future<void> insert(Map<String, dynamic> adjustment, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(
      DatabaseConstants.tableInventoryAdjustments,
      adjustment,
    );
  }

  Future<List<Map<String, dynamic>>> findAll(String branchId) async {
    final db = await _databaseService.database;
    return await db.query(
      DatabaseConstants.tableInventoryAdjustments,
      where: '${DatabaseConstants.columnBranchId} = ?',
      whereArgs: [branchId],
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
    );
  }
}
