import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';

class StockTransferDao {
  final DatabaseService _databaseService;

  StockTransferDao(this._databaseService);

  Future<void> insert(Map<String, dynamic> transfer, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(DatabaseConstants.tableStockTransfers, transfer);
  }

  Future<List<Map<String, dynamic>>> findAll() async {
    final db = await _databaseService.database;
    return await db.query(
      DatabaseConstants.tableStockTransfers,
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
    );
  }
}
