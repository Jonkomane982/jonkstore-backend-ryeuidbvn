import 'package:sqflite/sqflite.dart';
import '../../database/database_service.dart';
import '../../database/database_constants.dart';
import '../models/sync_task.dart';
import '../models/sync_state.dart';
import 'sync_queue.dart';
import 'dart:convert';

/// SQLite-based implementation of the [SyncQueue].
class SqliteSyncQueue implements SyncQueue {
  final DatabaseService _databaseService;

  SqliteSyncQueue(this._databaseService);

  @override
  Future<void> addTask(SyncTask task) async {
    final db = await _databaseService.database;
    await db.insert(
      DatabaseConstants.tableSyncQueue,
      {
        'id': task.id,
        'entityName': task.entityName,
        'entityId': task.entityId,
        'operation': task.operation,
        'data': jsonEncode(task.data),
        'state': task.state.name,
        'retryCount': task.retryCount,
        'lastError': task.lastError,
        'createdAt': task.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<SyncTask>> getPendingTasks() async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSyncQueue,
      where: 'state = ? OR state = ?',
      whereArgs: [SyncState.pending.name, SyncState.failed.name],
      orderBy: 'createdAt ASC',
    );

    return results.map((map) {
      return SyncTask(
        id: map['id'] as String,
        entityName: map['entityName'] as String,
        entityId: map['entityId'] as String,
        operation: map['operation'] as String,
        data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
        state: SyncState.values.firstWhere((e) => e.name == map['state']),
        retryCount: map['retryCount'] as int,
        lastError: map['lastError'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
    }).toList();
  }

  @override
  Future<void> updateTaskState(String taskId, SyncState state, {String? error}) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableSyncQueue,
      {
        'state': state.name,
        'lastError': error,
        if (state == SyncState.failed) 'retryCount': (await _getRetryCount(taskId)) + 1,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  @override
  Future<void> removeTask(String taskId) async {
    final db = await _databaseService.database;
    await db.delete(
      DatabaseConstants.tableSyncQueue,
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  @override
  Future<List<SyncTask>> getFailedTasks() async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSyncQueue,
      where: 'state = ?',
      whereArgs: [SyncState.failed.name],
    );
    return results.map((map) => _fromMap(map)).toList();
  }

  @override
  Future<void> clear() async {
    final db = await _databaseService.database;
    await db.delete(DatabaseConstants.tableSyncQueue);
  }

  Future<int> _getRetryCount(String taskId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      DatabaseConstants.tableSyncQueue,
      columns: ['retryCount'],
      where: 'id = ?',
      whereArgs: [taskId],
    );
    if (result.isNotEmpty) {
      return result.first['retryCount'] as int;
    }
    return 0;
  }

  SyncTask _fromMap(Map<String, dynamic> map) {
    return SyncTask(
      id: map['id'] as String,
      entityName: map['entityName'] as String,
      entityId: map['entityId'] as String,
      operation: map['operation'] as String,
      data: jsonDecode(map['data'] as String) as Map<String, dynamic>,
      state: SyncState.values.firstWhere((e) => e.name == map['state']),
      retryCount: map['retryCount'] as int,
      lastError: map['lastError'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
