import 'dart:async';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/datasources/local/product_local_datasource.dart';
import 'package:jonkstore/datasources/remote/product_remote_datasource.dart';
import 'package:jonkstore/sync/mixins/syncable_repository_mixin.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'product_repository.dart';

/// Production implementation of [ProductRepository].
/// 
/// Orchestrates data flow between local SQLite and remote REST API via synchronization.
class ProductRepositoryImpl with SyncableRepositoryMixin implements ProductRepository {
  final ProductLocalDataSource localDataSource;
  final ProductRemoteDataSource remoteDataSource;
  
  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'products';

  final _productStreamController = StreamController<List<Product>>.broadcast();

  ProductRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncQueue,
  });

  @override
  Future<Result<Product>> create(Product product) async {
    try {
      await localDataSource.insert(product);
      
      await enqueueSyncTask(
        entityId: product.id,
        operation: 'CREATE',
        data: product.toJson(),
      );

      _refreshStream();
      return Result.success(product);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Product>> update(Product product) async {
    try {
      await localDataSource.update(product);

      await enqueueSyncTask(
        entityId: product.id,
        operation: 'UPDATE',
        data: product.toJson(),
      );

      _refreshStream();
      return Result.success(product);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> delete(String id) async {
    try {
      final product = await localDataSource.findById(id);
      if (product == null) return Result.success(true);

      await localDataSource.delete(id);

      await enqueueSyncTask(
        entityId: id,
        operation: 'DELETE',
        data: product.toJson(),
      );

      _refreshStream();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Product?>> findById(String id) async {
    try {
      final product = await localDataSource.findById(id);
      return Result.success(product);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Product?>> findByBarcode(String barcode) async {
    try {
      final product = await localDataSource.findByBarcode(barcode);
      return Result.success(product);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Product>>> findAll() async {
    try {
      final products = await localDataSource.findAll();
      return Result.success(products);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Product>>> search(String query) async {
    try {
      final products = await localDataSource.search(query);
      return Result.success(products);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<int>> count() async {
    try {
      final result = await localDataSource.findAll();
      return Result.success(result.length);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> exists(String id) async {
    try {
      final product = await localDataSource.findById(id);
      return Result.success(product != null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Product>> watchAll() {
    _refreshStream();
    return _productStreamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refreshStream() async {
    try {
      final products = await localDataSource.findAll();
      _productStreamController.add(products);
    } catch (_) {}
  }
}
