import 'package:sqflite/sqflite.dart';
import '../../database/database_service.dart';
import '../../core/domain/models/product.dart';
import '../../database/database_constants.dart';

/// Local data source for Product operations using SQLite.
class ProductLocalDataSource {
  final DatabaseService _databaseService;

  ProductLocalDataSource(this._databaseService);

  Future<void> insert(Product product) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseConstants.tableProducts,
      product.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Product product) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableProducts,
      product.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _databaseService.database;
    await db.delete(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<Product?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Product.fromJson(results.first);
    }
    return null;
  }

  /// Production-grade barcode lookup.
  Future<Product?> findByBarcode(String barcode) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.columnBarcode} = ? AND ${DatabaseConstants.columnIsActive} = 1',
      whereArgs: [barcode],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Product.fromJson(results.first);
    }
    return null;
  }

  Future<List<Product>> findAll() async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableProducts,
      where: '${DatabaseConstants.columnIsDeleted} = 0',
    );
    return results.map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Product>> search(String query) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableProducts,
      where: '(${DatabaseConstants.columnName} LIKE ? OR ${DatabaseConstants.columnSku} LIKE ? OR ${DatabaseConstants.columnBarcode} LIKE ?) AND ${DatabaseConstants.columnIsDeleted} = 0',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return results.map((e) => Product.fromJson(e)).toList();
  }
}
