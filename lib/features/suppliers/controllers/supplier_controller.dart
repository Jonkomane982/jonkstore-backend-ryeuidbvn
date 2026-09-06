import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/supplier.dart';
import 'package:jonkstore/repositories/supplier_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';

class SupplierState {
  final bool isLoading;
  final String? errorMessage;
  final List<Supplier> suppliers;
  final List<Supplier> filteredSuppliers;
  final String searchQuery;

  SupplierState({
    this.isLoading = false,
    this.errorMessage,
    this.suppliers = const [],
    this.filteredSuppliers = const [],
    this.searchQuery = '',
  });

  SupplierState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Supplier>? suppliers,
    List<Supplier>? filteredSuppliers,
    String? searchQuery,
  }) {
    return SupplierState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      suppliers: suppliers ?? this.suppliers,
      filteredSuppliers: filteredSuppliers ?? this.filteredSuppliers,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class SupplierController extends StateNotifier<SupplierState> {
  final SupplierRepository _repository;

  SupplierController(this._repository) : super(SupplierState());

  Future<void> loadSuppliers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.findAll();
    result.fold(
      (suppliers) => state = state.copyWith(
        isLoading: false,
        suppliers: suppliers,
        filteredSuppliers: _filter(suppliers, state.searchQuery),
      ),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredSuppliers: _filter(state.suppliers, query),
    );
  }

  List<Supplier> _filter(List<Supplier> list, String query) {
    if (query.isEmpty) return list;
    final q = query.toLowerCase();
    return list.where((s) => 
      s.name.toLowerCase().contains(q) || 
      (s.contactName?.toLowerCase().contains(q) ?? false) ||
      (s.phone?.contains(q) ?? false)
    ).toList();
  }

  Future<void> deleteSupplier(String id) async {
    final result = await _repository.delete(id);
    result.fold((_) => loadSuppliers(), (f) => null);
  }
}

final supplierControllerProvider = StateNotifierProvider<SupplierController, SupplierState>((ref) {
  return SupplierController(ref.watch(supplierRepositoryProvider));
});
