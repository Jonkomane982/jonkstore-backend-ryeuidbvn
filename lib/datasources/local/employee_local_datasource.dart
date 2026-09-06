import '../../database/database_service.dart';
import '../../core/domain/models/employee.dart';
import '../../database/database_constants.dart';

/// Local data source for Employee operations using SQLite.
class EmployeeLocalDataSource {
  final DatabaseService _databaseService;

  EmployeeLocalDataSource(this._databaseService);

  Future<void> insert(Employee employee) async {
    final db = await _databaseService.database;
    await db.insert(DatabaseConstants.tableEmployees, employee.toJson());
  }

  Future<void> update(Employee employee) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableEmployees,
      employee.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [employee.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _databaseService.database;
    await db.delete(
      DatabaseConstants.tableEmployees,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<Employee?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableEmployees,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? Employee.fromJson(results.first) : null;
  }

  Future<List<Employee>> findAll() async {
    final db = await _databaseService.database;
    final results = await db.query(DatabaseConstants.tableEmployees);
    return results.map((e) => Employee.fromJson(e)).toList();
  }

  Future<List<Employee>> findByBranch(String branchId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableEmployees,
      where: 'branchId = ?',
      whereArgs: [branchId],
    );
    return results.map((e) => Employee.fromJson(e)).toList();
  }
}
