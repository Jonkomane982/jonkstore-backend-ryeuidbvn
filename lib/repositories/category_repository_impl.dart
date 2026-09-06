import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/domain/models/category.dart';
import '../core/domain/enums/sync_status.dart';
import '../core/network/result.dart';
import '../core/errors/failures.dart';
import '../datasources/local/category_local_datasource.dart';
import '../sync/queue/sync_queue.dart';
import '../sync/models/sync_task.dart';
import '../sync/models/sync_action.dart';
import 'category_repository.dart';

/// Production implementation of [CategoryRepository].
/// Handles data persistence, validation, and cloud synchronization queuing.
class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryLocalDataSource localDataSource;
  final SyncQueue syncQueue;

  final _categoryStreamController = StreamController<List<Category>>.broadcast();

  CategoryRepositoryImpl({
    required this.localDataSource,
    required this.syncQueue,
  });

  @override
  Future<Result<Category>> create(Category category) async {
    try {
      // 1. Validation: Prevent duplicate names
      final existing = await localDataSource.findByName(category.name);
      if (existing != null) {
        return Result.failure(const ValidationFailure('A category with this name already exists.'));
      }

      // 2. Prepare for persistence
      final newCategory = category.copyWith(
        syncStatus: SyncStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
      );

      // 3. Persist locally
      await localDataSource.insert(newCategory);

      // 4. Queue Synchronization Task
      await _queueSyncTask(newCategory, SyncAction.insert);

      _notifyListeners();
      return Result.success(newCategory);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Category>> update(Category category) async {
    try {
      // 1. Validation: Prevent duplicates (excluding self)
      final existing = await localDataSource.findByName(category.name, excludeId: category.id);
      if (existing != null) {
        return Result.failure(const ValidationFailure('Another category already uses this name.'));
      }

      final updatedCategory = category.copyWith(
        updatedAt: DateTime.now(),
        syncStatus: SyncStatus.updated,
        version: category.version + 1,
      );

      await localDataSource.update(updatedCategory);
      await _queueSyncTask(updatedCategory, SyncAction.update);

      _notifyListeners();
      return Result.success(updatedCategory);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> delete(String id) async {
    try {
      // 1. Validation: Safe deletion check
      final inUse = await localDataSource.isCategoryInUse(id);
      if (inUse) {
        return Result.failure(const ValidationFailure(
          'Cannot delete category. It is currently assigned to one or more products.',
        ));
      }
      
      final category = await localDataSource.findById(id);
      if (category == null) return Result.failure(const DatabaseFailure('Category not found'));

      // 2. Perform soft delete
      await localDataSource.softDelete(id, category.updatedBy ?? 'system');
      
      final deletedCategory = category.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        syncStatus: SyncStatus.deleted,
      );
      
      // 3. Queue Synchronization Task
      await _queueSyncTask(deletedCategory, SyncAction.delete);

      _notifyListeners();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> restore(String id) async {
    try {
      final category = await localDataSource.findById(id);
      if (category == null) return Result.failure(const DatabaseFailure('Category not found'));

      await localDataSource.restore(id, category.updatedBy ?? 'system');
      
      final restoredCategory = category.copyWith(
        isDeleted: false,
        deletedAt: null,
        syncStatus: SyncStatus.updated,
      );
      
      await _queueSyncTask(restoredCategory, SyncAction.update);

      _notifyListeners();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Category?>> findById(String id) async {
    try {
      final category = await localDataSource.findById(id);
      return Result.success(category);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Category>>> findAll({
    String? searchQuery,
    String? sortBy,
    bool ascending = true,
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    try {
      final categories = await localDataSource.findAll(
        searchQuery: searchQuery,
        sortBy: sortBy,
        ascending: ascending,
        limit: limit,
        offset: offset,
        includeDeleted: includeDeleted,
      );
      return Result.success(categories);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Category>> watchAll({bool includeDeleted = false}) {
    _notifyListeners(includeDeleted: includeDeleted);
    return _categoryStreamController.stream;
  }

  @override
  Future<Result<int>> count({bool includeDeleted = false}) async {
    try {
      final count = await localDataSource.count(includeDeleted: includeDeleted);
      return Result.success(count);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> sync() async {
    // This is handled by the specialized SyncEngine.
    return Result.success(null);
  }

  Future<void> _queueSyncTask(Category category, SyncAction action) async {
    final task = SyncTask(
      id: const Uuid().v4(),
      entityName: 'categories',
      entityId: category.id,
      operation: action.value,
      data: category.toJson(),
      createdAt: DateTime.now(),
    );
    await syncQueue.addTask(task);
  }

  void _notifyListeners({bool includeDeleted = false}) async {
    final result = await findAll(includeDeleted: includeDeleted);
    result.fold(
      (categories) => _categoryStreamController.add(categories),
      (failure) => _categoryStreamController.addError(failure),
    );
  }
}
