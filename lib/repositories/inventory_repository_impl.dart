import 'dart:async';
import 'package:jonkstore/core/domain/models/inventory.dart';
import 'package:jonkstore/core/domain/models/inventory_transaction.dart';
import 'package:jonkstore/core/domain/models/inventory_adjustment.dart';
import 'package:jonkstore/core/domain/models/inventory_count.dart';
import 'package:jonkstore/core/domain/models/stock_transfer.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/database/dao/inventory_dao.dart';
import 'package:jonkstore/database/dao/inventory_transaction_dao.dart';
import 'package:jonkstore/database/dao/inventory_adjustment_dao.dart';
import 'package:jonkstore/database/dao/inventory_count_dao.dart';
import 'package:jonkstore/database/dao/stock_transfer_dao.dart';
import 'package:jonkstore/database/database_service.dart';
import 'package:jonkstore/sync/mixins/syncable_repository_mixin.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'inventory_repository.dart';

/// Production implementation of [InventoryRepository].
///
/// Strictly enforces atomicity: Every stock change triggers an immutable transaction log.
class InventoryRepositoryImpl
    with SyncableRepositoryMixin
    implements InventoryRepository {
  final InventoryDao _inventoryDao;
  final InventoryTransactionDao _transactionDao;
  final InventoryAdjustmentDao _adjustmentDao;
  final InventoryCountDao _countDao;
  final StockTransferDao _transferDao;
  final DatabaseService _databaseService;

  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'inventory';

  final _streamController = StreamController<List<Inventory>>.broadcast();

  InventoryRepositoryImpl({
    required InventoryDao inventoryDao,
    required InventoryTransactionDao transactionDao,
    required InventoryAdjustmentDao adjustmentDao,
    required InventoryCountDao countDao,
    required StockTransferDao transferDao,
    required DatabaseService databaseService,
    required this.syncQueue,
  }) : _inventoryDao = inventoryDao,
       _transactionDao = transactionDao,
       _adjustmentDao = adjustmentDao,
       _countDao = countDao,
       _transferDao = transferDao,
       _databaseService = databaseService;

  @override
  Future<Result<Inventory>> upsertInventory(Inventory inventory) async {
    try {
      await _inventoryDao.upsert(inventory);
      await enqueueSyncTask(
        entityId: inventory.id,
        operation: 'UPSERT',
        data: inventory.toJson(),
      );
      _notify(inventory.branchId);
      return Result.success(inventory);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Inventory?>> findByProductId(
    String productId,
    String branchId,
  ) async {
    try {
      final item = await _inventoryDao.findByProductId(productId, branchId);
      return Result.success(item);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Inventory?>> findByBarcode(
    String barcode,
    String branchId,
  ) async {
    try {
      final item = await _inventoryDao.findByBarcode(barcode, branchId);
      return Result.success(item);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Inventory>>> findAll({
    String? branchId,
    bool lowStockOnly = false,
    bool outOfStockOnly = false,
    String? searchQuery,
    String? categoryId,
    String? supplierId,
    int? limit,
    int? offset,
  }) async {
    try {
      final results = await _inventoryDao.getInventoryWithProductInfo(
        branchId: branchId,
        lowStockOnly: lowStockOnly,
        outOfStockOnly: outOfStockOnly,
        searchQuery: searchQuery,
        categoryId: categoryId,
        supplierId: supplierId,
        limit: limit,
        offset: offset,
      );
      return Result.success(results.map((e) => Inventory.fromJson(e)).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Inventory>> watchInventory(String branchId) {
    _notify(branchId);
    return _streamController.stream;
  }

  @override
  Future<Result<void>> processStockMovement({
    required String inventoryId,
    required double newQuantity,
    required InventoryTransaction transaction,
  }) async {
    try {
      await _databaseService.transaction((txn) async {
        await _inventoryDao.updateStockLevel(
          inventoryId,
          newQuantity,
          txn: txn,
        );
        await _transactionDao.insert(transaction, txn: txn);
      });

      await enqueueSyncTask(
        entityId: transaction.id,
        operation: 'CREATE',
        data: transaction.toJson(),
      );

      _notify(transaction.branchId);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> recordTransaction(InventoryTransaction transaction) {
    return processStockMovement(
      inventoryId: transaction.inventoryId,
      newQuantity: transaction.newQuantity,
      transaction: transaction,
    );
  }

  @override
  Future<Result<List<InventoryTransaction>>> getTransactionHistory(
    String inventoryId,
  ) async {
    try {
      final history = await _transactionDao.findByInventoryId(inventoryId);
      return Result.success(history);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<InventoryTransaction>>> getProductHistory(
    String productId,
  ) async {
    try {
      final history = await _transactionDao.findByProductId(productId);
      return Result.success(history);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> createAdjustment(
    InventoryAdjustment adjustment,
    List<InventoryTransaction> transactions,
  ) async {
    try {
      await _databaseService.transaction((txn) async {
        await _adjustmentDao.insert(adjustment.toJson(), txn: txn);
        for (final tx in transactions) {
          await _transactionDao.insert(tx, txn: txn);
          await _inventoryDao.updateStockLevel(
            tx.inventoryId,
            tx.newQuantity,
            txn: txn,
          );
        }
      });

      await enqueueSyncTask(
        entityId: adjustment.id,
        operation: 'CREATE',
        data: {
          ...adjustment.toJson(),
          'transactions': transactions.map((e) => e.toJson()).toList(),
        },
      );

      _notify(adjustment.branchId);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> createStockCount(
    InventoryCount count,
    List<InventoryTransaction> transactions,
  ) async {
    try {
      await _databaseService.transaction((txn) async {
        await _countDao.insert(count, txn: txn);
        for (final tx in transactions) {
          await _transactionDao.insert(tx, txn: txn);
          await _inventoryDao.updateStockLevel(
            tx.inventoryId,
            tx.newQuantity,
            txn: txn,
          );
          // Update last count date on inventory record
          await txn.update(
            'inventory',
            {'last_count_date': count.countDate.toIso8601String()},
            where: 'id = ?',
            whereArgs: [tx.inventoryId],
          );
        }
      });

      await enqueueSyncTask(
        entityId: count.id,
        operation: 'CREATE',
        data: {
          ...count.toJson(),
          'transactions': transactions.map((e) => e.toJson()).toList(),
        },
      );

      _notify(count.branchId);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> createStockTransfer(
    StockTransfer transfer,
    List<InventoryTransaction> transactions,
  ) async {
    try {
      await _databaseService.transaction((txn) async {
        await _transferDao.insert(transfer.toJson(), txn: txn);
        for (final tx in transactions) {
          await _transactionDao.insert(tx, txn: txn);
          await _inventoryDao.updateStockLevel(
            tx.inventoryId,
            tx.newQuantity,
            txn: txn,
          );
        }
      });

      await enqueueSyncTask(
        entityId: transfer.id,
        operation: 'CREATE',
        data: {
          ...transfer.toJson(),
          'transactions': transactions.map((e) => e.toJson()).toList(),
        },
      );

      _notify(transfer.fromBranchId);
      _notify(transfer.toBranchId);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<StockTransfer>>> getStockTransfers() async {
    try {
      final rows = await _transferDao.findAll();
      return Result.success(
        rows.map((e) => StockTransfer.fromJson(e)).toList(),
      );
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<double>> getInventoryValuation(String branchId) async {
    try {
      final value = await _inventoryDao.getInventoryValuation(branchId);
      return Result.success(value);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _notify([String? branchId]) async {
    try {
      final items = await _inventoryDao.getInventoryWithProductInfo(
        branchId: branchId,
      );
      _streamController.add(items.map((e) => Inventory.fromJson(e)).toList());
    } catch (_) {}
  }
}
