import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/customer.dart';
import 'package:jonkstore/repositories/customer_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';

class CustomerState {
  final bool isLoading;
  final String? errorMessage;
  final List<Customer> customers;
  final List<Customer> filteredCustomers;
  final String searchQuery;

  CustomerState({
    this.isLoading = false,
    this.errorMessage,
    this.customers = const [],
    this.filteredCustomers = const [],
    this.searchQuery = '',
  });

  CustomerState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Customer>? customers,
    List<Customer>? filteredCustomers,
    String? searchQuery,
  }) {
    return CustomerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      customers: customers ?? this.customers,
      filteredCustomers: filteredCustomers ?? this.filteredCustomers,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CustomerController extends StateNotifier<CustomerState> {
  final CustomerRepository _repository;

  CustomerController(this._repository) : super(CustomerState());

  Future<void> loadCustomers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.findAll();
    result.fold(
      (customers) => state = state.copyWith(
        isLoading: false, 
        customers: customers,
        filteredCustomers: _filter(customers, state.searchQuery),
      ),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  void search(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredCustomers: _filter(state.customers, query),
    );
  }

  List<Customer> _filter(List<Customer> list, String query) {
    if (query.isEmpty) return list;
    final q = query.toLowerCase();
    return list.where((c) => 
      c.name.toLowerCase().contains(q) || 
      (c.phone?.contains(q) ?? false) || 
      (c.email?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  Future<void> deleteCustomer(String id) async {
    final result = await _repository.delete(id);
    result.fold((_) => loadCustomers(), (f) => null);
  }
}

final customerControllerProvider = StateNotifierProvider<CustomerController, CustomerState>((ref) {
  return CustomerController(ref.watch(customerRepositoryProvider));
});
