import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/category.dart';

/// Data Access Object for Category operations.
/// 
/// Handles low-level SQLite queries for the Categories module with strict adherence 
/// to the commercial 3NF schema and performance optimizations.
class CategoryDao {
  final DatabaseService _databaseService;

  CategoryDao(this._databaseService);

  /// Inserts or replaces a category record.
  Future<void> insert(Category category) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseConstants.tableCategories,
      category.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates a category record.
  Future<int> update(Category category) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableCategories,
      category.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [category.id],
    );
  }

  /// Soft deletes a category by setting is_deleted flag.
  Future<int> softDelete(String id, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableCategories,
      {
        DatabaseConstants.columnIsDeleted: 1,
        DatabaseConstants.columnDeletedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'PENDING',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Restores a soft-deleted category.
  Future<int> restore(String id, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableCategories,
      {
        DatabaseConstants.columnIsDeleted: 0,
        DatabaseConstants.columnDeletedAt: null,
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'PENDING',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Checks if the category is assigned to any active products.
  /// Mission-critical for safe deletion.
  Future<bool> isCategoryInUse(String categoryId) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConstants.tableProductCategories} WHERE ${DatabaseConstants.columnCategoryId} = ? AND ${DatabaseConstants.columnIsDeleted} = 0',
      [categoryId],
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  /// Finds a specific category by ID.
  Future<Category?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableCategories,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return Category.fromJson(results.first);
    }
    return null;
  }

  /// Finds a category by name for duplicate validation.
  Future<Category?> findByName(String name, {String? excludeId}) async {
    final db = await _databaseService.database;
    String where = 'name = ? AND ${DatabaseConstants.columnIsDeleted} = 0';
    List<dynamic> whereArgs = [name];
    
    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final results = await db.query(
      DatabaseConstants.tableCategories,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (results.isNotEmpty) {
      return Category.fromJson(results.first);
    }
    return null;
  }

  /// Retrieves categories with advanced filtering, sorting, and pagination.
  Future<List<Category>> findAll({
    String? searchQuery,
    String? sortBy = 'name',
    bool ascending = true,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    final db = await _databaseService.database;
    
    String where = includeDeleted ? '1=1' : '${DatabaseConstants.columnIsDeleted} = 0';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (name LIKE ? OR description LIKE ?)';
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    final order = ascending ? 'ASC' : 'DESC';
    final allowedSortColumns = ['name', 'created_at', 'updated_at'];
    final sortColumn = allowedSortColumns.contains(sortBy) ? sortBy : 'name';
    final orderBy = '$sortColumn $order';

    final results = await db.query(
      DatabaseConstants.tableCategories,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return results.map((e) => Category.fromJson(e)).toList();
  }

  /// Gets count of categories for statistics.
  Future<int> count({bool includeDeleted = false}) async {
    final db = await _databaseService.database;
    final where = includeDeleted ? '1=1' : '${DatabaseConstants.columnIsDeleted} = 0';
    final result = await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableCategories} WHERE $where');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Fetches category statistics including product count distribution.
  Future<Map<String, int>> getProductDistribution() async {
    final db = await _databaseService.database;
    final results = await db.rawQuery('''
      SELECT c.name, COUNT(pc.product_id) as total
      FROM ${DatabaseConstants.tableCategories} c
      LEFT JOIN ${DatabaseConstants.tableProductCategories} pc ON c.id = pc.category_id
      WHERE c.is_deleted = 0
      GROUP BY c.id
      ORDER BY total DESC
    ''');
    
    return {
      for (final row in results)
        row['name'] as String: row['total'] as int
    };
  }
}
