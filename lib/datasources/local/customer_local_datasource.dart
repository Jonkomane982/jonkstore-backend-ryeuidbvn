import '../../database/database_service.dart';
import '../../core/domain/models/customer.dart';
import '../../database/database_constants.dart';

/// Local data source for Customer operations using SQLite.
class CustomerLocalDataSource {
  final DatabaseService _databaseService;

  CustomerLocalDataSource(this._databaseService);

  Future<void> insert(Customer customer) async {
    final db = await _databaseService.database;
    await db.insert(DatabaseConstants.tableCustomers, customer.toJson());
  }

  Future<void> update(Customer customer) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableCustomers,
      customer.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _databaseService.database;
    await db.delete(
      DatabaseConstants.tableCustomers,
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
    );
    return results.isNotEmpty ? Customer.fromJson(results.first) : null;
  }

  Future<List<Customer>> findAll() async {
    final db = await _databaseService.database;
    final results = await db.query(DatabaseConstants.tableCustomers);
    return results.map((e) => Customer.fromJson(e)).toList();
  }

  Future<List<Customer>> search(String query) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableCustomers,
      where: 'name LIKE ? OR email LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return results.map((e) => Customer.fromJson(e)).toList();
  }
}
