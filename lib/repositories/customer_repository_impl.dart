import 'dart:async';
import 'package:jonkstore/core/domain/models/customer.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/datasources/local/customer_local_datasource.dart';
import 'package:jonkstore/datasources/remote/customer_remote_datasource.dart';
import 'package:jonkstore/sync/mixins/syncable_repository_mixin.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'customer_repository.dart';

/// Production implementation of [CustomerRepository] using SQLite.
class CustomerRepositoryImpl with SyncableRepositoryMixin implements CustomerRepository {
  final CustomerLocalDataSource localDataSource;
  final CustomerRemoteDataSource remoteDataSource;
  
  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'customers';

  final _streamController = StreamController<List<Customer>>.broadcast();

  CustomerRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncQueue,
  });

  @override
  Future<Result<Customer>> create(Customer customer) async {
    try {
      await localDataSource.insert(customer);
      
      await enqueueSyncTask(
        entityId: customer.id,
        operation: 'CREATE',
        data: customer.toJson(),
      );

      _refresh();
      return Result.success(customer);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Customer>> update(Customer customer) async {
    try {
      await localDataSource.update(customer);

      await enqueueSyncTask(
        entityId: customer.id,
        operation: 'UPDATE',
        data: customer.toJson(),
      );

      _refresh();
      return Result.success(customer);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> delete(String id) async {
    try {
      final customer = await localDataSource.findById(id);
      if (customer == null) return Result.success(true);

      await localDataSource.delete(id);

      await enqueueSyncTask(
        entityId: id,
        operation: 'DELETE',
        data: customer.toJson(),
      );

      _refresh();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Customer?>> findById(String id) async {
    try {
      final customer = await localDataSource.findById(id);
      return Result.success(customer);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Customer>>> findAll() async {
    try {
      final customers = await localDataSource.findAll();
      return Result.success(customers);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Customer>>> search(String query) async {
    try {
      final customers = await localDataSource.search(query);
      return Result.success(customers);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<int>> count() async {
    try {
      final customers = await localDataSource.findAll();
      return Result.success(customers.length);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Customer>> watchAll() {
    _refresh();
    return _streamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh() async {
    try {
      final customers = await localDataSource.findAll();
      _streamController.add(customers);
    } catch (_) {}
  }
}
