import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:jonkstore/core/domain/models/purchase_order.dart';
import 'package:jonkstore/core/domain/models/purchase_order_item.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/core/domain/enums/sync_status.dart';
import 'package:jonkstore/core/services/purchase_calculation_service.dart';
import 'package:jonkstore/repositories/purchase_repository.dart';
import 'package:jonkstore/features/products/controllers/product_controller.dart';
import 'package:jonkstore/features/suppliers/controllers/supplier_controller.dart';
import 'package:jonkstore/providers/repository_providers.dart';
import 'package:jonkstore/providers/auth_providers.dart';
import 'package:jonkstore/features/dashboard/providers/dashboard_providers.dart';

class DraftPurchaseItem {
  final Product product;
  final double quantity;
  final double unitCost;
  final double allocatedRunnerFee;

  DraftPurchaseItem({
    required this.product,
    required this.quantity,
    required this.unitCost,
    this.allocatedRunnerFee = 0,
  });

  double get total => quantity * unitCost;
  double get totalLandedCost => total + allocatedRunnerFee;
  double get landedUnitCost => quantity > 0 ? totalLandedCost / quantity : 0;
  double get expectedRevenue => quantity * product.sellingPrice;

  DraftPurchaseItem copyWith({
    double? quantity,
    double? unitCost,
    double? allocatedRunnerFee,
  }) {
    return DraftPurchaseItem(
      product: product,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      allocatedRunnerFee: allocatedRunnerFee ?? this.allocatedRunnerFee,
    );
  }
}

enum RunnerFeeAllocationMethod { proportional, equal }

class PurchaseState {
  final List<PurchaseOrder> orders;
  final List<DraftPurchaseItem> draftItems;
  final Supplier? selectedSupplier;
  final double runnerFee;
  final RunnerFeeAllocationMethod allocationMethod;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String? editingOrderId;
  final String? searchQuery;
  final String? statusFilter;

  PurchaseState({
    this.orders = const [],
    this.draftItems = const [],
    this.selectedSupplier,
    this.runnerFee = 0,
    this.allocationMethod = RunnerFeeAllocationMethod.proportional,
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.editingOrderId,
    this.searchQuery,
    this.statusFilter,
  });

  double get subtotal => draftItems.fold(0, (sum, item) => sum + item.total);
  double get totalInvestment => subtotal + runnerFee;
  double get totalAmount => totalInvestment;
  double get expectedRevenue => draftItems.fold(0, (sum, item) => sum + item.expectedRevenue);
  double get expectedProfit => expectedRevenue - totalInvestment;
  double get totalUnits => draftItems.fold(0, (sum, item) => sum + item.quantity);
  
  PurchaseState copyWith({
    List<PurchaseOrder>? orders,
    List<DraftPurchaseItem>? draftItems,
    Supplier? selectedSupplier,
    double? runnerFee,
    RunnerFeeAllocationMethod? allocationMethod,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    String? editingOrderId,
    String? searchQuery,
    String? statusFilter,
  }) {
    return PurchaseState(
      orders: orders ?? this.orders,
      draftItems: draftItems ?? this.draftItems,
      selectedSupplier: selectedSupplier ?? this.selectedSupplier,
      runnerFee: runnerFee ?? this.runnerFee,
      allocationMethod: allocationMethod ?? this.allocationMethod,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      editingOrderId: editingOrderId ?? this.editingOrderId,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class PurchaseController extends StateNotifier<PurchaseState> {
  final PurchaseRepository _repository;
  final PurchaseCalculationService _calculationService;
  final Ref _ref;

  PurchaseController(this._repository, this._calculationService, this._ref) : super(PurchaseState());

  Future<void> loadOrders({String? searchQuery, String? status}) async {
    state = state.copyWith(
      isLoading: true, 
      errorMessage: null,
      searchQuery: searchQuery,
      statusFilter: status,
    );
    
    final business = await _ref.read(currentBusinessProvider.future);
    final result = await _repository.findAll(
      branchId: business?.id,
      searchQuery: searchQuery ?? state.searchQuery,
      status: status ?? state.statusFilter,
    );

    result.fold(
      (orders) => state = state.copyWith(isLoading: false, orders: orders),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  Future<void> loadOrderForEditing(String orderId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final orderResult = await _repository.findById(orderId);
    final itemsResult = await _repository.getOrderItems(orderId);
    
    orderResult.fold(
      (order) {
        if (order == null) {
          state = state.copyWith(isLoading: false, errorMessage: 'Order not found');
          return;
        }
        
        itemsResult.fold(
          (items) {
            final products = _ref.read(productControllerProvider).products;
            final suppliers = _ref.read(supplierControllerProvider).suppliers;
            
            final supplier = suppliers.firstWhere((s) => s.id == order.supplierId);
            
            final draftItems = items.map((item) {
              final product = products.firstWhere((p) => p.id == item.productId);
              return DraftPurchaseItem(
                product: product,
                quantity: item.quantity,
                unitCost: item.unitCost,
                allocatedRunnerFee: item.allocatedRunnerFee,
              );
            }).toList();

            state = state.copyWith(
              isLoading: false,
              editingOrderId: orderId,
              selectedSupplier: supplier,
              runnerFee: order.otherCosts,
              allocationMethod: order.allocationMethod == 'EQUAL' 
                  ? RunnerFeeAllocationMethod.equal 
                  : RunnerFeeAllocationMethod.proportional,
              draftItems: draftItems,
            );
          },
          (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
        );
      },
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  void addToDraft(Product product, double quantity, double unitCost) {
    final newItem = DraftPurchaseItem(product: product, quantity: quantity, unitCost: unitCost);
    final updatedItems = [...state.draftItems, newItem];
    _updateDraftWithFees(updatedItems);
  }

  void removeFromDraft(String productId) {
    final updatedItems = state.draftItems.where((i) => i.product.id != productId).toList();
    _updateDraftWithFees(updatedItems);
  }

  void updateRunnerFee(double fee) {
    state = state.copyWith(runnerFee: fee);
    _updateDraftWithFees(state.draftItems);
  }

  void updateAllocationMethod(RunnerFeeAllocationMethod method) {
    state = state.copyWith(allocationMethod: method);
    _updateDraftWithFees(state.draftItems);
  }

  void _updateDraftWithFees(List<DraftPurchaseItem> items) {
    if (items.isEmpty) {
      state = state.copyWith(draftItems: []);
      return;
    }

    if (state.runnerFee <= 0) {
      state = state.copyWith(draftItems: items.map((e) => e.copyWith(allocatedRunnerFee: 0)).toList());
      return;
    }

    final calculationItems = items.map((e) => PurchaseOrderItem(
      id: e.product.id,
      purchaseOrderId: '',
      productId: e.product.id,
      quantity: e.quantity,
      unitCost: e.unitCost,
      totalCost: e.total,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )).toList();

    Map<String, double> allocations;
    if (state.allocationMethod == RunnerFeeAllocationMethod.proportional) {
      allocations = _calculationService.calculateProportionalRunnerFeeAllocation(state.runnerFee, calculationItems);
    } else {
      allocations = _calculationService.calculateEqualRunnerFeeAllocation(state.runnerFee, calculationItems);
    }

    final updatedItems = items.map((item) {
      return item.copyWith(allocatedRunnerFee: allocations[item.product.id] ?? 0);
    }).toList();

    state = state.copyWith(draftItems: updatedItems);
  }

  void selectSupplier(Supplier? supplier) {
    state = state.copyWith(selectedSupplier: supplier);
  }

  Future<void> createOrUpdateOrder() async {
    if (state.selectedSupplier == null || state.draftItems.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    final business = await _ref.read(currentBusinessProvider.future);
    final user = _ref.read(currentUserProvider);
    
    if (business == null) {
      state = state.copyWith(isLoading: false, errorMessage: 'Business context not found');
      return;
    }

    final orderId = state.editingOrderId ?? const Uuid().v4();
    final now = DateTime.now();

    final order = PurchaseOrder(
      id: orderId,
      supplierId: state.selectedSupplier!.id,
      businessId: business.id,
      branchId: business.id,
      orderNumber: state.editingOrderId == null ? 'PO-${now.millisecondsSinceEpoch}' : null,
      orderDate: now,
      subtotal: state.subtotal,
      otherCosts: state.runnerFee,
      allocationMethod: state.allocationMethod.name.toUpperCase(),
      totalAmount: state.totalInvestment,
      status: 'ordered',
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pending,
      createdBy: user?.id,
      updatedBy: user?.id,
    );

    final items = state.draftItems.map((item) {
      return PurchaseOrderItem(
        id: const Uuid().v4(),
        purchaseOrderId: orderId,
        productId: item.product.id,
        sku: item.product.sku,
        quantity: item.quantity,
        unitCost: item.unitCost,
        totalCost: item.total,
        allocatedRunnerFee: item.allocatedRunnerFee,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.pending,
        createdBy: user?.id,
      );
    }).toList();

    final result = state.editingOrderId == null 
        ? await _repository.createOrder(order, items)
        : await _repository.updateOrder(order, items);

    result.fold(
      (success) {
        state = state.copyWith(
          isLoading: false, 
          isSuccess: true, 
          draftItems: [], 
          selectedSupplier: null,
          runnerFee: 0,
          editingOrderId: null,
        );
        loadOrders();
      },
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  void reset() {
    state = PurchaseState();
  }
}

final purchaseCalculationServiceProvider = Provider((ref) => PurchaseCalculationService());

final purchaseControllerProvider = StateNotifierProvider<PurchaseController, PurchaseState>((ref) {
  return PurchaseController(
    ref.watch(purchaseRepositoryProvider),
    ref.watch(purchaseCalculationServiceProvider),
    ref,
  );
});
