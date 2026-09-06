import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/customer.dart';

class CustomerDao {
  final DatabaseService _databaseService;

  CustomerDao(this._databaseService);

  Future<void> insert(Customer customer, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    await executor.insert(
      DatabaseConstants.tableCustomers,
      customer.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(Customer customer, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    return await executor.update(
      DatabaseConstants.tableCustomers,
      customer.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> softDelete(String id, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    return await executor.update(
      DatabaseConstants.tableCustomers,
      {
        DatabaseConstants.columnIsDeleted: 1,
        DatabaseConstants.columnDeletedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'DELETED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> restore(String id, {Transaction? txn}) async {
    final executor = txn ?? await _databaseService.database;
    return await executor.update(
      DatabaseConstants.tableCustomers,
      {
        DatabaseConstants.columnIsDeleted: 0,
        DatabaseConstants.columnDeletedAt: null,
        DatabaseConstants.columnSyncStatus: 'UPDATED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<Customer?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableCustomers,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? Customer.fromJson(results.first) : null;
  }

  Future<List<Customer>> findAll({
    String? searchQuery,
    bool includeDeleted = false,
  }) async {
    final db = await _databaseService.database;
    String where = includeDeleted ? '1=1' : '${DatabaseConstants.columnIsDeleted} = 0';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (name LIKE ? OR phone LIKE ? OR email LIKE ?)';
      final q = '%$searchQuery%';
      args.addAll([q, q, q]);
    }

    final results = await db.query(
      DatabaseConstants.tableCustomers,
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return results.map((e) => Customer.fromJson(e)).toList();
  }

  /// Calculates real spending statistics for a customer from the sales table.
  Future<Map<String, dynamic>> getCustomerStats(String customerId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_sales,
        SUM(total_amount) as total_spent,
        MAX(created_at) as last_purchase_date
      FROM ${DatabaseConstants.tableSales}
      WHERE ${DatabaseConstants.columnCustomerId} = ? AND status = 'COMPLETED'
    ''', [customerId]);
    
    return result.first;
  }
}
