import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/supplier.dart';
import '../../../core/network/result.dart';
import '../../../repositories/supplier_repository.dart';
import '../../../providers/repository_providers.dart';

/// UI state for the Suppliers module.
class SupplierListState {
  final bool isLoading;
  final String? errorMessage;
  final List<Supplier> suppliers;
  final String searchQuery;
  final bool? isActiveFilter;
  final String sortBy;
  final bool ascending;
  final int? totalCount;

  SupplierListState({
    this.isLoading = false,
    this.errorMessage,
    this.suppliers = const [],
    this.searchQuery = '',
    this.isActiveFilter,
    this.sortBy = 'name',
    this.ascending = true,
    this.totalCount,
  });

  SupplierListState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Supplier>? suppliers,
    String? searchQuery,
    bool? isActiveFilter,
    bool clearActiveFilter = false,
    String? sortBy,
    bool? ascending,
    int? totalCount,
    bool clearErrorMessage = false,
  }) {
    return SupplierListState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      suppliers: suppliers ?? this.suppliers,
      searchQuery: searchQuery ?? this.searchQuery,
      isActiveFilter:
          clearActiveFilter ? null : isActiveFilter ?? this.isActiveFilter,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class SupplierListController extends StateNotifier<SupplierListState> {
  final SupplierRepository _repo;

  SupplierListController(this._repo) : super(SupplierListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    final list = await _repo.findAll(
      searchQuery: state.searchQuery.trim().isEmpty ? null : state.searchQuery,
      sortBy: state.sortBy,
      ascending: state.ascending,
      isActive: state.isActiveFilter,
      includeDeleted: false,
    );
    final count = await _repo.count(
      searchQuery: state.searchQuery.trim().isEmpty ? null : state.searchQuery,
      isActive: state.isActiveFilter,
    );
    list.fold(
      (suppliers) {
        final n = count.fold<int>((c) => c, (_) => suppliers.length);
        state = state.copyWith(
          isLoading: false,
          suppliers: suppliers,
          totalCount: n,
        );
      },
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  void updateSearch(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    load();
  }

  void filterActive(bool? active) {
    if (active == null) {
      state = state.copyWith(clearActiveFilter: true);
    } else {
      state = state.copyWith(isActiveFilter: active);
    }
    load();
  }

  void sortBy(String column) {
    if (state.sortBy == column) {
      state = state.copyWith(ascending: !state.ascending);
    } else {
      state = state.copyWith(sortBy: column, ascending: true);
    }
    load();
  }

  Future<Result<Supplier>> create(Supplier s) async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.create(s);
    result.fold(
      (_) => load(),
      (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
    );
    return result;
  }

  Future<Result<Supplier>> update(Supplier s) async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.update(s);
    result.fold(
      (_) => load(),
      (f) => state = state.copyWith(isLoading: false, errorMessage: f.message),
    );
    return result;
  }

  Future<Result<Supplier>> setActive(String id, bool active) async {
    final result = await _repo.setActive(id, active);
    result.fold((_) => load(), (f) {
      state = state.copyWith(errorMessage: f.message);
    });
    return result;
  }

  Future<Result<bool>> delete(String id) async {
    final result = await _repo.delete(id);
    result.fold((_) => load(), (f) {
      state = state.copyWith(errorMessage: f.message);
    });
    return result;
  }

  Future<Result<bool>> restore(String id) async {
    final result = await _repo.restore(id);
    result.fold((_) => load(), (f) {
      state = state.copyWith(errorMessage: f.message);
    });
    return result;
  }
}

final supplierListControllerProvider =
    StateNotifierProvider<SupplierListController, SupplierListState>((ref) {
  return SupplierListController(ref.watch(supplierRepositoryProvider));
});
