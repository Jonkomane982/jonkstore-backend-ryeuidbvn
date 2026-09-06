import 'dart:async';
import 'package:jonkstore/core/domain/models/employee.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/datasources/local/employee_local_datasource.dart';
import 'package:jonkstore/datasources/remote/employee_remote_datasource.dart';
import 'package:jonkstore/sync/mixins/syncable_repository_mixin.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'employee_repository.dart';

/// Production implementation of [EmployeeRepository] using SQLite.
class EmployeeRepositoryImpl with SyncableRepositoryMixin implements EmployeeRepository {
  final EmployeeLocalDataSource localDataSource;
  final EmployeeRemoteDataSource remoteDataSource;
  
  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'employees';

  final _streamController = StreamController<List<Employee>>.broadcast();

  EmployeeRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncQueue,
  });

  @override
  Future<Result<Employee>> create(Employee employee) async {
    try {
      await localDataSource.insert(employee);
      await enqueueSyncTask(
        entityId: employee.id,
        operation: 'CREATE',
        data: employee.toJson(),
      );
      _refresh();
      return Result.success(employee);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Employee>> update(Employee employee) async {
    try {
      await localDataSource.update(employee);
      await enqueueSyncTask(
        entityId: employee.id,
        operation: 'UPDATE',
        data: employee.toJson(),
      );
      _refresh();
      return Result.success(employee);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> delete(String id) async {
    try {
      final employee = await localDataSource.findById(id);
      if (employee == null) return Result.success(true);
      await localDataSource.delete(id);
      await enqueueSyncTask(
        entityId: id,
        operation: 'DELETE',
        data: employee.toJson(),
      );
      _refresh();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Employee?>> findById(String id) async {
    try {
      final employee = await localDataSource.findById(id);
      return Result.success(employee);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Employee>>> findAll() async {
    try {
      final employees = await localDataSource.findAll();
      return Result.success(employees);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Employee>>> findByBranch(String branchId) async {
    try {
      final employees = await localDataSource.findByBranch(branchId);
      return Result.success(employees);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Employee>> watchAll() {
    _refresh();
    return _streamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh() async {
    try {
      final employees = await localDataSource.findAll();
      _streamController.add(employees);
    } catch (_) {}
  }
}
