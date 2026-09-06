import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../database_constants.dart';
import '../../core/domain/models/supplier.dart';

/// Data Access Object for Supplier operations.
///
/// Low-level SQLite queries for the Suppliers module with strict adherence
/// to the commercial 3NF schema and performance optimizations (indexed
/// search columns: name, code, phone).
class SupplierDao {
  final DatabaseService _databaseService;

  SupplierDao(this._databaseService);

  /// Inserts or replaces a supplier record.
  Future<void> insert(Supplier supplier) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseConstants.tableSuppliers,
      supplier.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates a supplier record.
  Future<int> update(Supplier supplier) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableSuppliers,
      supplier.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [supplier.id],
    );
  }

  /// Toggles the is_active flag for a supplier.
  Future<int> setActive(String id, bool isActive, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableSuppliers,
      {
        DatabaseConstants.columnIsActive: isActive ? 1 : 0,
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'UPDATED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Soft deletes a supplier by setting is_deleted flag.
  Future<int> softDelete(String id, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableSuppliers,
      {
        DatabaseConstants.columnIsDeleted: 1,
        DatabaseConstants.columnDeletedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'DELETED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Restores a soft-deleted supplier.
  Future<int> restore(String id, String userId) async {
    final db = await _databaseService.database;
    return await db.update(
      DatabaseConstants.tableSuppliers,
      {
        DatabaseConstants.columnIsDeleted: 0,
        DatabaseConstants.columnDeletedAt: null,
        DatabaseConstants.columnUpdatedBy: userId,
        DatabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        DatabaseConstants.columnSyncStatus: 'UPDATED',
      },
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  /// Checks if a supplier has existing dependent records that would block safe deletion.
  ///
  /// Scans:
  ///   - purchase_orders (if the table exists yet)
  ///   - products linked to a supplier_id column if present
  ///
  /// Missing tables are treated as "no references" and allow deletion.
  Future<bool> isSupplierInUse(String supplierId) async {
    final db = await _databaseService.database;
    int totalRefs = 0;

    try {
      final poCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [DatabaseConstants.tablePurchaseOrders],
      );
      if (poCheck.isNotEmpty) {
        final po = await db.rawQuery(
          'SELECT COUNT(*) FROM ${DatabaseConstants.tablePurchaseOrders} '
          'WHERE ${DatabaseConstants.columnSupplierId} = ? '
          'AND ${DatabaseConstants.columnIsDeleted} = 0',
          [supplierId],
        );
        totalRefs += Sqflite.firstIntValue(po) ?? 0;
      }
    } catch (_) {}

    try {
      final tableProducts = DatabaseConstants.tableProducts;
      final cols = await db.rawQuery('PRAGMA table_info("$tableProducts")');
      final hasSupplierFk = cols.any((row) {
        final n = row['name'];
        return n != null &&
            n.toString().toLowerCase() ==
                DatabaseConstants.columnSupplierId.toLowerCase();
      });
      if (hasSupplierFk) {
        final colSupplierId = DatabaseConstants.columnSupplierId;
        final colIsDeleted = DatabaseConstants.columnIsDeleted;
        final prod = await db.rawQuery(
          'SELECT COUNT(*) FROM $tableProducts '
          'WHERE $colSupplierId = ? '
          'AND $colIsDeleted = 0',
          [supplierId],
        );
        totalRefs += Sqflite.firstIntValue(prod) ?? 0;
      }
    } catch (_) {}

    return totalRefs > 0;
  }

  /// Finds a specific supplier by ID.
  Future<Supplier?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSuppliers,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return Supplier.fromJson(results.first);
    }
    return null;
  }

  /// Finds a supplier by name (for duplicate prevention during create/update).
  Future<Supplier?> findByName(String name, {String? excludeId}) async {
    final db = await _databaseService.database;
    String where =
        '${DatabaseConstants.columnName} = ? AND ${DatabaseConstants.columnIsDeleted} = 0';
    List<dynamic> whereArgs = [name];
    if (excludeId != null) {
      where += ' AND ${DatabaseConstants.columnId} != ?';
      whereArgs.add(excludeId);
    }
    final results = await db.query(
      DatabaseConstants.tableSuppliers,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (results.isNotEmpty) return Supplier.fromJson(results.first);
    return null;
  }

  /// Finds a supplier by unique code.
  Future<Supplier?> findByCode(String code, {String? excludeId}) async {
    final db = await _databaseService.database;
    String where =
        '${DatabaseConstants.columnCode} = ? AND ${DatabaseConstants.columnIsDeleted} = 0';
    List<dynamic> whereArgs = [code];
    if (excludeId != null) {
      where += ' AND ${DatabaseConstants.columnId} != ?';
      whereArgs.add(excludeId);
    }
    final results = await db.query(
      DatabaseConstants.tableSuppliers,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (results.isNotEmpty) return Supplier.fromJson(results.first);
    return null;
  }

  /// Retrieves suppliers with database-backed search, filtering, sorting and
  /// pagination.
  ///
  /// Search fields covered by indexes: name, code, contactName, phone.  Using
  /// [activeFilter] if non-null narrows to active-only or inactive-only
  /// suppliers.  includeDeleted=false by default.
  Future<List<Supplier>> findAll({
    String? searchQuery,
    String? sortBy = 'name',
    bool ascending = true,
    bool? isActive,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    final db = await _databaseService.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeDeleted) {
      whereClauses.add('${DatabaseConstants.columnIsDeleted} = 0');
    }
    if (isActive != null) {
      whereClauses.add('${DatabaseConstants.columnIsActive} = ?');
      whereArgs.add(isActive ? 1 : 0);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add(
        '(${DatabaseConstants.columnName} LIKE ? OR ${DatabaseConstants.columnCode} LIKE ? OR ${DatabaseConstants.columnContactName} LIKE ? OR ${DatabaseConstants.columnPhone} LIKE ?)',
      );
      whereArgs.addAll([q, q, q, q]);
    }

    final sort = ['name', 'code', 'created_at', 'updated_at'].contains(sortBy)
        ? sortBy!
        : 'name';
    final order = ascending ? 'ASC' : 'DESC';
    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');

    final results = await db.query(
      DatabaseConstants.tableSuppliers,
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: '$sort $order',
      limit: limit,
      offset: offset,
    );

    return results.map((e) => Supplier.fromJson(e)).toList();
  }

  /// Counts suppliers matching the search/active filters (statistics & pagination UIs).
  Future<int> count({
    String? searchQuery,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    final db = await _databaseService.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (!includeDeleted) {
      whereClauses.add('${DatabaseConstants.columnIsDeleted} = 0');
    }
    if (isActive != null) {
      whereClauses.add('${DatabaseConstants.columnIsActive} = ?');
      whereArgs.add(isActive ? 1 : 0);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereClauses.add(
        '(${DatabaseConstants.columnName} LIKE ? OR ${DatabaseConstants.columnCode} LIKE ? OR ${DatabaseConstants.columnContactName} LIKE ? OR ${DatabaseConstants.columnPhone} LIKE ?)',
      );
      whereArgs.addAll([q, q, q, q]);
    }

    final where = whereClauses.isEmpty ? '1=1' : whereClauses.join(' AND ');
    final r = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseConstants.tableSuppliers} WHERE $where',
      whereArgs.isEmpty ? null : whereArgs,
    );
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Supplier Detail aggregate queries for Supplier Details screen
  // ---------------------------------------------------------------------------

  /// Total number of products supplied (counts products referencing this supplier
  /// when the FK is defined on the products table).
  Future<int> countProductsForSupplier(String supplierId) async {
    final db = await _databaseService.database;
    try {
      final tableProducts = DatabaseConstants.tableProducts;
      final cols = await db.rawQuery('PRAGMA table_info("$tableProducts")');
      final hasFk = cols.any((row) {
        final n = row['name'];
        return n != null &&
            n.toString().toLowerCase() ==
                DatabaseConstants.columnSupplierId.toLowerCase();
      });
      if (!hasFk) return 0;
      final colSupplierId = DatabaseConstants.columnSupplierId;
      final colIsDeleted = DatabaseConstants.columnIsDeleted;
      final r = await db.rawQuery(
        'SELECT COUNT(*) FROM $tableProducts '
        'WHERE $colSupplierId = ? '
        'AND $colIsDeleted = 0',
        [supplierId],
      );
      return Sqflite.firstIntValue(r) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Aggregate purchase totals for a supplier.  Returns a map with keys
  /// `total_purchase_value`, `total_paid`, `outstanding_balance`,
  /// `purchase_count`.
  Future<Map<String, double>> getPurchaseTotals(String supplierId) async {
    final db = await _databaseService.database;
    final empty = {
      'total_purchase_value': 0.0,
      'total_paid': 0.0,
      'outstanding_balance': 0.0,
      'purchase_count': 0.0,
    };
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [DatabaseConstants.tablePurchaseOrders],
      );
      if (tables.isEmpty) return empty;
      final r = await db.rawQuery(
        'SELECT COUNT(*) AS c, '
        'SUM(${DatabaseConstants.columnTotalAmount}) AS total, '
        'SUM(${DatabaseConstants.columnPaidAmount}) AS paid '
        'FROM ${DatabaseConstants.tablePurchaseOrders} '
        'WHERE ${DatabaseConstants.columnSupplierId} = ? '
        'AND ${DatabaseConstants.columnIsDeleted} = 0',
        [supplierId],
      );
      if (r.isEmpty) return empty;
      final total = (r.first['total'] as num?)?.toDouble() ?? 0.0;
      final paid = (r.first['paid'] as num?)?.toDouble() ?? 0.0;
      return {
        'total_purchase_value': total,
        'total_paid': paid,
        'outstanding_balance': (total - paid).clamp(0.0, double.infinity),
        'purchase_count': (r.first['c'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (_) {
      return empty;
    }
  }

  /// Recent purchases for the most recent N transactions with the supplier.
  /// Each row map contains: id, order_number, purchase_date, status,
  /// total_amount, paid_amount.
  Future<List<Map<String, dynamic>>> getRecentPurchases(
    String supplierId, {
    int limit = 10,
  }) async {
    final db = await _databaseService.database;
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [DatabaseConstants.tablePurchaseOrders],
      );
      if (tables.isEmpty) return [];
      return await db.rawQuery(
        'SELECT id, ${DatabaseConstants.columnOrderNumber}, '
        '${DatabaseConstants.columnPurchaseDate} AS purchase_date, '
        '${DatabaseConstants.columnStatus}, '
        '${DatabaseConstants.columnTotalAmount}, '
        '${DatabaseConstants.columnPaidAmount} '
        'FROM ${DatabaseConstants.tablePurchaseOrders} '
        'WHERE ${DatabaseConstants.columnSupplierId} = ? '
        'AND ${DatabaseConstants.columnIsDeleted} = 0 '
        'ORDER BY COALESCE(${DatabaseConstants.columnPurchaseDate}, ${DatabaseConstants.columnCreatedAt}) DESC '
        'LIMIT ?',
        [supplierId, limit],
      );
    } catch (_) {
      return [];
    }
  }
}
