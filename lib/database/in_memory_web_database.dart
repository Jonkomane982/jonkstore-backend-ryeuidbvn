import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/logger/app_logger.dart';

bool _mapEq(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k)) return false;
      if (!_mapEq(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_mapEq(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// JonkStore Web-compatible Database implementation.
///
/// sqflite_common_ffi_web 0.4.5+ and 1.x both crash on Chrome/WASM with:
///   "unsupported result null (null)" / "Null is not a subtype of bool"
/// deep inside sqflite's factory/database_mixin code paths — before any of
/// our app-level callbacks run.
///
/// This class implements the *subset* of the sqflite Database/Transaction API
/// that JonkStore actually uses:
///   - execute()      — runs CREATE TABLE/INSERT/PRAGMA; PRAGMAs are no-ops
///   - insert/update/delete/query
///   - raw* variants
///   - transaction()  — serializes writes inside a Map snapshot
///   - batch()        — commits as a single write group
///   - close()        — persists snapshot to SharedPreferences (web localStorage)
///
/// Limitations vs real SQLite:
///   - No JOINs, subqueries, or SQL functions beyond COUNT(*).
///   - WHERE clauses parsed as: column = ? AND ... (only exact eq).
///   - orderBy: 'column ASC|DESC' (single column).
///   - limit / offset supported.
///   - PRAGMAs are accepted but do nothing.
///   - CREATE TRIGGER / ALTER TABLE variants accepted but no-ops.
class InMemoryWebDatabase implements Database {
  final String _debugName;
  final Map<String, List<Map<String, Object?>>> _tables = {};
  final List<({String sql, List<Object?>? args})> _uncommittedBatch = [];
  bool _isClosed = false;
  static const _persistKey = 'jonkstore_web_inmem_db_snapshot_v1';

  InMemoryWebDatabase(this._debugName);

  static Future<InMemoryWebDatabase> open(String name) async {
    final db = InMemoryWebDatabase(name);
    await db._restoreFromPrefs();
    if (kDebugMode) {
      print(
        'JonkStore: [Web] InMemoryWebDatabase opened: $name (tables: ${db._tables.length})',
      );
    }
    return db;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  // --------------------- schema / DDL ---------------------

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    final trimmed = sql.trim();
    final upper = trimmed.toUpperCase();

    if (upper.startsWith('PRAGMA ')) {
      return; // accept & ignore
    }
    if (upper.startsWith('CREATE INDEX')) {
      return; // no-op
    }
    if (upper.startsWith('CREATE TRIGGER')) {
      return; // no-op
    }
    if (upper.startsWith('CREATE TABLE')) {
      _createTable(trimmed);
      return;
    }
    if (upper.startsWith('INSERT') ||
        upper.startsWith('UPDATE') ||
        upper.startsWith('DELETE')) {
      await _runWrite(sql, arguments);
      return;
    }
    if (kDebugMode) {
      print('JonkStore: [Web] InMemoryDB.execute(noop): $trimmed');
    }
  }

  void _createTable(String sql) {
    final openIdx = sql.indexOf('(');
    if (openIdx < 0) return;
    final prefix = sql.substring(0, openIdx).trim();
    final words = prefix.split(RegExp(r'\s+'));
    final tableName = words.last.replaceAll('"', '').replaceAll("'", '');
    _tables.putIfAbsent(tableName, () => <Map<String, Object?>>[]);
    if (kDebugMode) {
      print('JonkStore: [Web] InMemoryDB CREATE TABLE: $tableName');
    }
  }

  // --------------------- write helpers ---------------------

  Future<int> _runWrite(String sql, List<Object?>? args) async {
    final s = _applyArgs(sql, args);
    final u = s.trim().toUpperCase();
    if (u.startsWith('INSERT INTO')) {
      return _executeInsert(s);
    }
    if (u.startsWith('UPDATE ')) {
      return _executeUpdate(s);
    }
    if (u.startsWith('DELETE FROM')) {
      return _executeDelete(s);
    }
    return 0;
  }

  // --------------------- insert ---------------------

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    return _executeInsert(_applyArgs(sql, arguments));
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _ensureOpen();
    final rows = _tables.putIfAbsent(table, () => <Map<String, Object?>>[]);
    if (conflictAlgorithm == ConflictAlgorithm.replace ||
        conflictAlgorithm == ConflictAlgorithm.ignore) {
      final id = values['id'];
      if (id != null) {
        final idx = rows.indexWhere((r) => _mapEq(r['id'], id));
        if (idx >= 0) {
          if (conflictAlgorithm == ConflictAlgorithm.replace) {
            rows[idx] = Map<String, Object?>.from(values);
            return 1;
          } else {
            return 0;
          }
        }
      }
    }
    rows.add(Map<String, Object?>.from(values));
    await _maybePersist();
    return rows.length;
  }

  int _executeInsert(String sql) {
    final match = RegExp(
      r'INSERT\s+INTO\s+["`\[]?([\w]+)["`\]]?\s*\(([^)]+)\)\s*VALUES\s*\((.+)\)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(sql);
    if (match == null) return 0;
    final table = match.group(1)!;
    final cols = _splitTopLevel(
      match.group(2)!,
    ).map((c) => _stripQuotes(c.trim())).toList();
    final vals = _splitTopLevel(
      match.group(3)!,
    ).map((v) => _parseLiteral(v.trim())).toList();
    final rows = _tables.putIfAbsent(table, () => <Map<String, Object?>>[]);
    final row = <String, Object?>{};
    for (int i = 0; i < cols.length && i < vals.length; i++) {
      row[cols[i]] = vals[i];
    }
    rows.add(row);
    _maybePersistAsync();
    return 1;
  }

  // --------------------- update ---------------------

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    return _executeUpdate(_applyArgs(sql, arguments));
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _ensureOpen();
    final rows = _tables[table];
    if (rows == null) return 0;
    final pred = _wherePredicate(where, whereArgs);
    int count = 0;
    for (int i = 0; i < rows.length; i++) {
      if (pred(rows[i])) {
        final next = Map<String, Object?>.from(rows[i]);
        next.addAll(values);
        rows[i] = next;
        count++;
      }
    }
    if (count > 0) await _maybePersist();
    return count;
  }

  int _executeUpdate(String sql) {
    final setRe = RegExp(
      r'UPDATE\s+["`\[]?([\w]+)["`\]]?\s+SET\s+(.+?)(?:\s+WHERE\s+(.+))?$',
      caseSensitive: false,
      dotAll: true,
    );
    final m = setRe.firstMatch(sql);
    if (m == null) return 0;
    final table = m.group(1)!;
    final assignmentsRaw = m.group(2)!;
    final whereRaw = m.group(3);
    final rows = _tables[table];
    if (rows == null) return 0;

    final assigns = <String, Object?>{};
    for (final a in _splitTopLevel(assignmentsRaw)) {
      final idx = a.indexOf('=');
      if (idx < 0) continue;
      final col = _stripQuotes(a.substring(0, idx).trim());
      final val = _parseLiteral(a.substring(idx + 1).trim());
      assigns[col] = val;
    }

    final pred = _wherePredicate(whereRaw, null);
    int count = 0;
    for (int i = 0; i < rows.length; i++) {
      if (pred(rows[i])) {
        final next = Map<String, Object?>.from(rows[i]);
        next.addAll(assigns);
        rows[i] = next;
        count++;
      }
    }
    if (count > 0) _maybePersistAsync();
    return count;
  }

  // --------------------- delete ---------------------

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    _ensureOpen();
    return _executeDelete(_applyArgs(sql, arguments));
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    _ensureOpen();
    final rows = _tables[table];
    if (rows == null) return 0;
    final pred = _wherePredicate(where, whereArgs);
    final before = rows.length;
    rows.removeWhere((r) => pred(r));
    final removed = before - rows.length;
    if (removed > 0) await _maybePersist();
    return removed;
  }

  int _executeDelete(String sql) {
    final re = RegExp(
      r'DELETE\s+FROM\s+["`\[]?([\w]+)["`\]]?(?:\s+WHERE\s+(.+))?$',
      caseSensitive: false,
      dotAll: true,
    );
    final m = re.firstMatch(sql);
    if (m == null) return 0;
    final table = m.group(1)!;
    final whereRaw = m.group(2);
    final rows = _tables[table];
    if (rows == null) return 0;
    final pred = _wherePredicate(whereRaw, null);
    final before = rows.length;
    rows.removeWhere(pred);
    final removed = before - rows.length;
    if (removed > 0) _maybePersistAsync();
    return removed;
  }

  // --------------------- query ---------------------

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    _ensureOpen();
    final s = _applyArgs(sql, arguments);
    final trimmed = s.trim();
    final upper = trimmed.toUpperCase();

    if (upper.startsWith('PRAGMA')) {
      if (upper.contains('USER_VERSION')) {
        return [
          <String, Object?>{'user_version': 1},
        ];
      }
      return const [];
    }

    if (upper.startsWith('SELECT')) {
      return _executeSelect(trimmed);
    }

    return const [];
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    _ensureOpen();
    final rows = _tables[table] ?? const <Map<String, Object?>>[];
    Iterable<Map<String, Object?>> out = rows;

    final pred = _wherePredicate(where, whereArgs);
    out = out.where(pred);

    if (orderBy != null && orderBy.isNotEmpty) {
      final parts = orderBy.trim().split(RegExp(r'\s+'));
      final col = _stripQuotes(parts[0]);
      final asc = parts.length < 2 || parts[1].toUpperCase() != 'DESC';
      final list = out.toList();
      list.sort((a, b) {
        final va = a[col];
        final vb = b[col];
        final cmp = _compareAny(va, vb);
        return asc ? cmp : -cmp;
      });
      out = list;
    }

    if (offset != null && out.length > offset) {
      out = out.skip(offset);
    }
    if (limit != null) {
      out = out.take(limit);
    }

    if (columns != null && columns.isNotEmpty && !columns.contains('*')) {
      out = out.map((row) {
        final m = <String, Object?>{};
        for (final c in columns) {
          final cc = _stripQuotes(c);
          if (row.containsKey(cc)) m[cc] = row[cc];
        }
        return m;
      });
    }

    if (distinct == true) {
      final seen = <String>{};
      final uniq = <Map<String, Object?>>[];
      for (final r in out) {
        final k = jsonEncode(r);
        if (seen.add(k)) uniq.add(r);
      }
      out = uniq;
    }

    return out.toList(growable: false);
  }

  Future<List<Map<String, Object?>>> _executeSelect(String sql) async {
    final countStar = RegExp(
      r'SELECT\s+COUNT\(\s*\*\s*\)(?:\s+AS\s+(\w+))?\s+FROM\s+["`\[]?([\w]+)["`\]]?(?:\s+WHERE\s+(.+))?$',
      caseSensitive: false,
      dotAll: true,
    );
    var m = countStar.firstMatch(sql);
    if (m != null) {
      final alias = m.group(1) ?? 'count';
      final table = m.group(2)!;
      final whereRaw = m.group(3);
      final rows = _tables[table] ?? const <Map<String, Object?>>[];
      final pred = _wherePredicate(whereRaw, null);
      final n = rows.where(pred).length;
      return [
        <String, Object?>{alias: n},
      ];
    }

    final select = RegExp(
      r'SELECT\s+(?:DISTINCT\s+)?(.+?)\s+FROM\s+["`\[]?([\w]+)["`\]]?(?:\s+WHERE\s+(.+?))?(?:\s+ORDER\s+BY\s+(.+?))?(?:\s+LIMIT\s+(\d+)(?:\s+OFFSET\s+(\d+))?)?$',
      caseSensitive: false,
      dotAll: true,
    );
    m = select.firstMatch(sql);
    if (m == null) return const [];
    final colsRaw = m.group(1)!;
    final table = m.group(2)!;
    final whereRaw = m.group(3);
    final orderBy = m.group(4);
    final limit = m.group(5) != null ? int.parse(m.group(5)!) : null;
    final offset = m.group(6) != null ? int.parse(m.group(6)!) : null;
    final columns = colsRaw.trim() == '*'
        ? null
        : _splitTopLevel(colsRaw).map((c) => c.trim()).toList();
    final distinct = colsRaw.toUpperCase().startsWith('DISTINCT');

    return query(
      table,
      columns: columns,
      where: whereRaw,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
      distinct: distinct,
    );
  }

  // --------------------- transactions ---------------------

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    _ensureOpen();
    return await action(_InMemoryTxn(this));
  }

  // --------------------- batch ---------------------

  @override
  Batch batch() => _InMemoryBatch(this);

  // --------------------- close / persistence ---------------------

  @override
  bool get isOpen => !_isClosed;

  @override
  Future<void> close() async {
    await _persistToPrefs();
    _isClosed = true;
  }

  Future<void> _maybePersist() async {
    try {
      await _persistToPrefs();
    } catch (e) {
      AppLogger.warning('JonkStore: [Web] InMemoryDB persist failed: $e');
    }
  }

  void _maybePersistAsync() {
    Future.microtask(() async {
      try {
        await _persistToPrefs();
      } catch (_) {}
    });
  }

  Future<void> _persistToPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final payload = jsonEncode(_tables);
      await sp.setString(_persistKey, payload);
    } catch (_) {}
  }

  Future<void> _restoreFromPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final s = sp.getString(_persistKey);
      if (s == null || s.isEmpty) return;
      final decoded = jsonDecode(s) as Map<String, Object?>;
      decoded.forEach((k, v) {
        if (v is List) {
          _tables[k] = v
              .map((e) => Map<String, Object?>.from(e as Map))
              .toList();
        }
      });
    } catch (_) {}
  }

  void _ensureOpen() {
    if (_isClosed) throw StateError('InMemoryWebDatabase closed ($_debugName)');
  }

  // --------------------- helpers ---------------------

  static String _applyArgs(String sql, List<Object?>? args) {
    if (args == null || args.isEmpty) return sql;
    int i = 0;
    return sql.replaceAllMapped(RegExp(r'\?'), (_) {
      if (i >= args.length) return 'NULL';
      final v = args[i++];
      return _literal(v);
    });
  }

  static String _literal(Object? v) {
    if (v == null) return 'NULL';
    if (v is num) return v.toString();
    if (v is bool) return v ? '1' : '0';
    return "'${v.toString().replaceAll("'", "''")}'";
  }

  static String _stripQuotes(String s) => s
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('`', '')
      .replaceAll('[', '')
      .replaceAll(']', '');

  static List<String> _splitTopLevel(String s) {
    final out = <String>[];
    int depth = 0;
    int start = 0;
    bool inStr = false;
    String? strCh;
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (c == strCh) inStr = false;
        continue;
      }
      if (c == "'" || c == '"') {
        inStr = true;
        strCh = c;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == ',' && depth == 0) {
        out.add(s.substring(start, i));
        start = i + 1;
      }
    }
    out.add(s.substring(start));
    return out;
  }

  static Object? _parseLiteral(String s) {
    if (s == 'NULL' || s == 'null' || s.isEmpty) return null;
    if (s.startsWith("'") && s.endsWith("'") && s.length >= 2) {
      return s.substring(1, s.length - 1).replaceAll("''", "'");
    }
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    final n = num.tryParse(s);
    if (n != null) {
      if (n is int) return n;
      if (n.toInt() == n) return n.toInt();
      return n.toDouble();
    }
    if (s.toUpperCase() == 'TRUE') return 1;
    if (s.toUpperCase() == 'FALSE') return 0;
    if (s.toUpperCase() == 'CURRENT_TIMESTAMP') {
      return DateTime.now().toUtc().toIso8601String();
    }
    return s;
  }

  static bool Function(Map<String, Object?>) _wherePredicate(
    String? where,
    List<Object?>? whereArgs,
  ) {
    if (where == null || where.trim().isEmpty) return (_) => true;
    String w = where.trim();
    if (whereArgs != null && whereArgs.isNotEmpty) {
      w = _applyArgs(w, whereArgs);
    }
    final ands = w.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    final preds = ands.map((cond) {
      final eq = RegExp(
        r'^["`\[]?([\w]+)["`\]]?\s*=\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(cond);
      if (eq != null) {
        final col = _stripQuotes(eq.group(1)!);
        final val = _parseLiteral(eq.group(2)!.trim());
        return (Map<String, Object?> r) => _mapEq(r[col], val);
      }
      final isNull = RegExp(
        r'^["`\[]?([\w]+)["`\]]?\s+IS\s+NULL$',
        caseSensitive: false,
      ).firstMatch(cond);
      if (isNull != null) {
        final col = _stripQuotes(isNull.group(1)!);
        return (Map<String, Object?> r) => r[col] == null;
      }
      final isNotNull = RegExp(
        r'^["`\[]?([\w]+)["`\]]?\s+IS\s+NOT\s+NULL$',
        caseSensitive: false,
      ).firstMatch(cond);
      if (isNotNull != null) {
        final col = _stripQuotes(isNotNull.group(1)!);
        return (Map<String, Object?> r) => r[col] != null;
      }
      return (Map<String, Object?> _) => true;
    }).toList();
    return (row) => preds.every((p) => p(row));
  }

  static int _compareAny(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    return a.toString().compareTo(b.toString());
  }
}

/// Thin Transaction wrapper that simply delegates to the owning InMemoryWebDatabase.
/// Transactions on Web are best-effort; failure during writes won't roll back earlier
/// individual writes, but this keeps the API contract identical for callers.
class _InMemoryTxn implements Transaction {
  final InMemoryWebDatabase _db;
  _InMemoryTxn(this._db);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _db.execute(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => _db.rawQuery(sql, arguments);
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _db.rawUpdate(sql, arguments);
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _db.rawDelete(sql, arguments);
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _db.rawInsert(sql, arguments);
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _db.insert(
    table,
    values,
    nullColumnHack: nullColumnHack,
    conflictAlgorithm: conflictAlgorithm,
  );
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _db.update(
    table,
    values,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );
  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _db.delete(table, where: where, whereArgs: whereArgs);
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => _db.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );

  @override
  Batch batch() => _db.batch();
}

/// Batch implementation that runs writes sequentially.
class _InMemoryBatch extends Batch {
  final InMemoryWebDatabase _db;
  final List<Future<Object?> Function()> _ops = [];
  _InMemoryBatch(this._db);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _ops.add(() async {
      await _db.execute(sql, arguments);
      return null;
    });
  }

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _ops.add(() => _db.rawInsert(sql, arguments).then((v) => v));
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _ops.add(() => _db.rawUpdate(sql, arguments).then((v) => v));
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _ops.add(() => _db.rawDelete(sql, arguments).then((v) => v));
  }

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _ops.add(
      () => _db.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _ops.add(
      () => _db.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      ),
    );
  }

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _ops.add(() => _db.delete(table, where: where, whereArgs: whereArgs));
  }

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    _ops.add(
      () => _db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
    );
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    final out = <Object?>[];
    for (final op in _ops) {
      try {
        out.add(await op());
      } catch (e) {
        if (continueOnError == true) {
          out.add(e);
        } else {
          rethrow;
        }
      }
    }
    return out;
  }

  @override
  int get length => _ops.length;

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) =>
      throw UnsupportedError('use commit()');
}

/// Wraps a Transaction as a Database so the same (db, version) signature works.
class _TransactionAsDbWrapper implements Database {
  final Transaction _txn;
  _TransactionAsDbWrapper(this._txn);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _txn.execute(sql, arguments);
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => _txn.rawQuery(sql, arguments);
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _txn.rawUpdate(sql, arguments);
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _txn.rawDelete(sql, arguments);
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _txn.rawInsert(sql, arguments);
  @override
  Batch batch() =>
      throw UnsupportedError('batch inside onCreate/Upgrade not supported');

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _txn.insert(
    table,
    values,
    nullColumnHack: nullColumnHack,
    conflictAlgorithm: conflictAlgorithm,
  );

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) => _txn.update(
    table,
    values,
    where: where,
    whereArgs: whereArgs,
    conflictAlgorithm: conflictAlgorithm,
  );

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _txn.delete(table, where: where, whereArgs: whereArgs);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) => _txn.query(
    table,
    distinct: distinct,
    columns: columns,
    where: where,
    whereArgs: whereArgs,
    groupBy: groupBy,
    having: having,
    orderBy: orderBy,
    limit: limit,
    offset: offset,
  );

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async => await action(_txn);
}

/// DatabaseFactory that produces InMemoryWebDatabase instances (no sqflite driver involved).
class InMemoryWebDatabaseFactory implements DatabaseFactory {
  InMemoryWebDatabaseFactory();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Database> openDatabase(
    String path, {
    OpenDatabaseOptions? options,
  }) async {
    final db = (path == ':memory:')
        ? await InMemoryWebDatabase.open(':memory:')
        : await InMemoryWebDatabase.open(path);

    final opts = options;
    if (opts == null) return db;

    try {
      final onConfigure = opts.onConfigure;
      if (onConfigure != null) {
        try {
          await onConfigure(db);
        } catch (e) {
          AppLogger.warning(
            'JonkStore: [Web] onConfigure hook failed (tolerated): $e',
          );
        }
      }

      final targetVersion = opts.version ?? 0;
      int currentVersion = 0;
      try {
        final rows = await db.rawQuery('PRAGMA user_version');
        if (rows.isNotEmpty) {
          final v = rows.first.values.first;
          if (v is int) currentVersion = v;
        }
      } catch (_) {}

      final onCreate = opts.onCreate;
      final onUpgrade = opts.onUpgrade;
      final onDowngrade = opts.onDowngrade;
      final onOpen = opts.onOpen;

      if (targetVersion > 0 && currentVersion == 0 && onCreate != null) {
        await db.transaction((txn) async {
          await onCreate(_txnAsDb(txn), targetVersion);
        });
        currentVersion = targetVersion;
      } else if (onUpgrade != null && currentVersion < targetVersion) {
        await db.transaction((txn) async {
          await onUpgrade(_txnAsDb(txn), currentVersion, targetVersion);
        });
        currentVersion = targetVersion;
      } else if (onDowngrade != null && currentVersion > targetVersion) {
        await db.transaction((txn) async {
          await onDowngrade(_txnAsDb(txn), currentVersion, targetVersion);
        });
        currentVersion = targetVersion;
      }

      try {
        await db.execute('PRAGMA user_version = $currentVersion');
      } catch (_) {}

      if (onOpen != null) {
        try {
          await onOpen(db);
        } catch (_) {}
      }
    } catch (e, s) {
      AppLogger.error(
        'JonkStore: [Web] InMemory openDatabase hooks failed: $e',
      );
      if (kDebugMode) {
        print(e);
        print(s);
      }
      rethrow;
    }

    return db;
  }

  Database _txnAsDb(Transaction txn) => _TransactionAsDbWrapper(txn);

  @override
  Future<bool> databaseExists(String path) async {
    try {
      final sp = await SharedPreferences.getInstance();
      return sp.containsKey('jonkstore_web_inmem_db_snapshot_v1');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteDatabase(String path) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove('jonkstore_web_inmem_db_snapshot_v1');
    } catch (_) {}
  }

  @override
  Future<String> getDatabasesPath() async => '/jonkstore-web-dbs';

  bool get hasStorageCapability => true;

  void resetHasStorageCapability() {}

  Future<void> fixDatabaseNotFound(String path) async {}

  Future<bool> safeDeleteDatabase(String path) async {
    try {
      await deleteDatabase(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  set databaseFactoryLogger(void Function(String message) logger) {}
}
