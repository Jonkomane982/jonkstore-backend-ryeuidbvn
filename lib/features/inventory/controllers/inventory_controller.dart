import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/inventory.dart';
import 'package:jonkstore/core/domain/models/inventory_transaction.dart';
import 'package:jonkstore/repositories/inventory_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';

/// State for the Inventory management feature.
class InventoryState {
  final bool isLoading;
  final String? errorMessage;
  final List<Inventory> inventoryItems;
  final List<InventoryTransaction> transactionHistory;

  InventoryState({
    this.isLoading = false,
    this.errorMessage,
    this.inventoryItems = const [],
    this.transactionHistory = const [],
  });

  InventoryState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Inventory>? inventoryItems,
    List<InventoryTransaction>? transactionHistory,
  }) {
    return InventoryState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      inventoryItems: inventoryItems ?? this.inventoryItems,
      transactionHistory: transactionHistory ?? this.transactionHistory,
    );
  }
}

/// Controller responsible for managing inventory levels and transaction logs.
class InventoryController extends StateNotifier<InventoryState> {
  final InventoryRepository _repository;

  InventoryController(this._repository) : super(InventoryState());

  /// Loads inventory for a specific branch.
  Future<void> loadInventory(String branchId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final result = await _repository.findAll();
    
    result.fold(
      (items) {
        final branchItems = items.where((i) => i.branchId == branchId).toList();
        state = state.copyWith(isLoading: false, inventoryItems: branchItems);
      },
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Records a new inventory transaction (Adjustment, Damage, etc.)
  Future<void> recordMovement(InventoryTransaction transaction) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final result = await _repository.recordTransaction(transaction);
    
    result.fold(
      (success) => loadInventory(transaction.branchId),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Loads movement history for a specific product.
  Future<void> loadHistory(String productId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final result = await _repository.getTransactionHistory(productId);
    
    result.fold(
      (history) => state = state.copyWith(isLoading: false, transactionHistory: history),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }
}

/// Provider for the InventoryController.
final inventoryControllerProvider = StateNotifierProvider<InventoryController, InventoryState>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return InventoryController(repository);
});
