import 'dart:async';
import 'package:jonkstore/core/domain/models/purchase_order.dart';
import 'package:jonkstore/core/domain/models/purchase_order_item.dart';
import 'package:jonkstore/core/domain/models/inventory_transaction.dart';
import 'package:jonkstore/core/domain/enums/inventory_transaction_type.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/core/services/purchase_calculation_service.dart';
import 'package:jonkstore/datasources/local/purchase_local_datasource.dart';
import 'package:jonkstore/datasources/remote/purchase_remote_datasource.dart';
import 'package:jonkstore/database/database_service.dart';
import 'package:jonkstore/database/dao/inventory_dao.dart';
import 'package:jonkstore/database/dao/inventory_transaction_dao.dart';
import 'package:jonkstore/sync/mixins/syncable_repository_mixin.dart';
import 'package:jonkstore/sync/queue/sync_queue.dart';
import 'package:uuid/uuid.dart';
import 'purchase_repository.dart';

/// Production implementation of [PurchaseRepository].
class PurchaseRepositoryImpl with SyncableRepositoryMixin implements PurchaseRepository {
  final PurchaseLocalDataSource localDataSource;
  final PurchaseRemoteDataSource remoteDataSource;
  final InventoryDao inventoryDao;
  final InventoryTransactionDao transactionDao;
  final DatabaseService databaseService;
  final PurchaseCalculationService calculationService;
  
  @override
  final SyncQueue syncQueue;

  @override
  String get entityName => 'purchase_orders';

  final _streamController = StreamController<List<PurchaseOrder>>.broadcast();

  PurchaseRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.inventoryDao,
    required this.transactionDao,
    required this.databaseService,
    required this.calculationService,
    required this.syncQueue,
  });

  @override
  Future<Result<PurchaseOrder>> createOrder(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    try {
      final allocations = _calculateAllocations(order, items);
      
      await localDataSource.insertOrder(order, items, runnerFeeAllocations: allocations);
      
      await enqueueSyncTask(
        entityId: order.id,
        operation: 'CREATE',
        data: {
          ...order.toJson(),
          'items': items.map((e) => e.toJson()).toList(),
          'allocations': allocations,
        },
      );

      _refresh(order.branchId);
      return Result.success(order);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<PurchaseOrder>> updateOrder(PurchaseOrder order, List<PurchaseOrderItem> items) async {
     try {
      final allocations = _calculateAllocations(order, items);
      
      await localDataSource.insertOrder(order, items, runnerFeeAllocations: allocations);
      
      await enqueueSyncTask(
        entityId: order.id,
        operation: 'UPDATE',
        data: {
          ...order.toJson(),
          'items': items.map((e) => e.toJson()).toList(),
          'allocations': allocations,
        },
      );

      _refresh(order.branchId);
      return Result.success(order);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  Map<String, double> _calculateAllocations(PurchaseOrder order, List<PurchaseOrderItem> items) {
    if (order.otherCosts <= 0) return {};
    
    if (order.allocationMethod == 'EQUAL') {
      return calculationService.calculateEqualRunnerFeeAllocation(order.otherCosts, items);
    } else {
      return calculationService.calculateProportionalRunnerFeeAllocation(order.otherCosts, items);
    }
  }

  @override
  Future<Result<PurchaseOrder>> updateStatus(String orderId, String status) async {
    try {
      await localDataSource.updateOrderStatus(orderId, status);
      final order = await localDataSource.findById(orderId);
      
      if (order != null) {
        await enqueueSyncTask(
          entityId: orderId,
          operation: 'UPDATE',
          data: {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        );
        _refresh(order.branchId);
        return Result.success(order);
      }
      return Result.failure(const DatabaseFailure('Order not found'));
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> receiveStock({
    required String orderId,
    required List<PurchaseOrderItem> receivedItems,
    bool isFinal = false,
  }) async {
    try {
      final order = await localDataSource.findById(orderId);
      if (order == null) return Result.failure(const DatabaseFailure('Order not found'));

      await databaseService.transaction((txn) async {
        // 1. Process each received item
        bool allReceived = true;
        final currentItems = await localDataSource.getOrderItems(orderId);
        
        for (final receivedItem in receivedItems) {
          final originalItem = currentItems.firstWhere((i) => i.id == receivedItem.id);
          final newTotalReceived = originalItem.receivedQuantity + receivedItem.quantity;
          
          if (newTotalReceived < originalItem.quantity) {
            allReceived = false;
          }

          // Landed Cost Calculation logic for the audit log
          // Use stored allocation
          final landedUnitCost = calculationService.calculateLandedUnitCost(
            originalItem.unitCost, 
            originalItem.quantity, 
            originalItem.allocatedRunnerFee,
          );

          // Update PO item received quantity
          await txn.update(
            'purchase_order_items',
            {
              'received_quantity': newTotalReceived,
              'updated_at': DateTime.now().toIso8601String(),
              'sync_status': 'UPDATED',
            },
            where: 'id = ?',
            whereArgs: [receivedItem.id],
          );

          // 2. Update Inventory
          final inv = await inventoryDao.findByProductId(receivedItem.productId, order.branchId);
          if (inv != null) {
            final newQty = inv.quantity + receivedItem.quantity;
            await inventoryDao.updateStockLevel(inv.id, newQty, txn: txn);
            
            // 3. Create Inventory Transaction with Landed Cost
            final tx = InventoryTransaction(
              id: const Uuid().v4(),
              inventoryId: inv.id,
              productId: receivedItem.productId,
              branchId: order.branchId,
              quantityChange: receivedItem.quantity,
              previousQuantity: inv.quantity,
              newQuantity: newQty,
              type: InventoryTransactionType.purchase,
              referenceId: orderId,
              unitCost: landedUnitCost,
              userId: order.updatedBy ?? 'system',
              transactionDate: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await transactionDao.insert(tx, txn: txn);
          }
        }

        // 4. Update Order Status
        String newStatus = isFinal ? 'RECEIVED' : (allReceived ? 'RECEIVED' : 'PARTIAL');
        await txn.update(
          'purchase_orders',
          {
            'status': newStatus,
            'received_date': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'UPDATED',
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
      });

      await enqueueSyncTask(
        entityId: orderId,
        operation: 'UPDATE',
        data: {
          'status': isFinal ? 'RECEIVED' : 'PARTIAL',
          'received_items': receivedItems.map((e) => e.toJson()).toList(),
          'received_at': DateTime.now().toIso8601String(),
        },
      );

      _refresh(order.branchId);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<PurchaseOrder?>> findById(String id) async {
    try {
      final order = await localDataSource.findById(id);
      return Result.success(order);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<PurchaseOrder>>> findAll({
    String? branchId,
    String? status,
    String? searchQuery,
  }) async {
    try {
      final data = await localDataSource.findAll(
        branchId: branchId,
        status: status,
        searchQuery: searchQuery,
      );
      return Result.success(data.map((e) => PurchaseOrder.fromJson(e)).toList());
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<PurchaseOrderItem>>> getOrderItems(String orderId) async {
    try {
      final items = await localDataSource.getOrderItems(orderId);
      return Result.success(items);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<double>> getTotalInvestment(String branchId) async {
    try {
      final value = await localDataSource.getTotalInvestment(branchId);
      return Result.success(value);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<PurchaseOrder>> watchOrders({String? branchId}) {
    _refresh(branchId);
    return _streamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  Future<void> _refresh([String? branchId]) async {
    try {
      final orders = await findAll(branchId: branchId);
      orders.fold(
        (list) => _streamController.add(list),
        (failure) => _streamController.addError(failure),
      );
    } catch (_) {}
  }
}
