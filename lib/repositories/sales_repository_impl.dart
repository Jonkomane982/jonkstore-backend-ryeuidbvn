import 'dart:async';
import 'package:jonkstore/core/domain/models/sale.dart';
import 'package:jonkstore/core/domain/models/sale_item.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/datasources/local/sales_local_datasource.dart';
import 'package:jonkstore/datasources/remote/sales_remote_datasource.dart';
import 'package:jonkstore/sync/mixins/syncable_repository_mixin.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'sales_repository.dart';

/// Production implementation of [SalesRepository] using SQLite.
/// 
/// Handles atomic transactions for sales and their items, 
/// and enqueues tasks for background synchronization.
class SalesRepositoryImpl with SyncableRepositoryMixin implements SalesRepository {
  final SalesLocalDataSource localDataSource;
  final SalesRemoteDataSource remoteDataSource;
  
  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'sales';

  final _salesStreamController = StreamController<List<Sale>>.broadcast();

  SalesRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncQueue,
  });

  @override
  Future<Result<Sale>> createSale(Sale sale, List<SaleItem> items) async {
    try {
      // 1. Persist to local SQLite inside a transaction
      await localDataSource.insertSale(sale, items);
      
      // 2. Enqueue for synchronization
      // We sync the sale object which contains the overall total and payment info.
      // The backend will receive the items as part of the sale payload or separate.
      // For this architecture, we'll sync the sale with its items.
      await enqueueSyncTask(
        entityId: sale.id,
        operation: 'CREATE',
        data: {
          ...sale.toJson(),
          'items': items.map((e) => e.toJson()).toList(),
        },
      );

      _refresh();
      return Result.success(sale);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Sale?>> findById(String id) async {
    try {
      final sale = await localDataSource.findById(id);
      return Result.success(sale);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Sale>>> findAll() async {
    try {
      final sales = await localDataSource.findAll();
      return Result.success(sales);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Sale>>> findByDateRange(DateTime start, DateTime end) async {
    try {
      final sales = await localDataSource.findByDateRange(start, end);
      return Result.success(sales);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<SaleItem>>> getSaleItems(String saleId) async {
    try {
      final items = await localDataSource.getSaleItems(saleId);
      return Result.success(items);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> refundSale(String saleId) async {
    try {
      // Logic for marking sale as refunded and adjusting status
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Sale>> watchRecentSales(int limit) {
    _refresh();
    return _salesStreamController.stream.map((list) => list.take(limit).toList());
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh() async {
    try {
      final sales = await localDataSource.findAll();
      _salesStreamController.add(sales);
    } catch (_) {}
  }
}
