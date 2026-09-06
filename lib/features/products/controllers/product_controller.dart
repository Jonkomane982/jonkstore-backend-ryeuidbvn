import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/repositories/product_repository.dart';
import 'package:jonkstore/providers/repository_providers.dart';

/// State for the Product management feature.
class ProductState {
  final bool isLoading;
  final String? errorMessage;
  final List<Product> products;
  final List<Product> filteredProducts;
  final String searchQuery;

  ProductState({
    this.isLoading = false,
    this.errorMessage,
    this.products = const [],
    this.filteredProducts = const [],
    this.searchQuery = '',
  });

  ProductState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Product>? products,
    List<Product>? filteredProducts,
    String? searchQuery,
  }) {
    return ProductState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Controller responsible for managing products logic.
class ProductController extends StateNotifier<ProductState> {
  final ProductRepository _repository;

  ProductController(this._repository) : super(ProductState());

  /// Loads all products from the database.
  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    final result = await _repository.findAll();
    
    result.fold(
      (products) {
        state = state.copyWith(
          isLoading: false,
          products: products,
          filteredProducts: _filterProducts(products, state.searchQuery),
        );
      },
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Searches products by name, SKU, or barcode.
  void searchProducts(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredProducts: _filterProducts(state.products, query),
    );
  }

  List<Product> _filterProducts(List<Product> products, String query) {
    if (query.isEmpty) return products;
    final lowercaseQuery = query.toLowerCase();
    return products.where((p) {
      return p.name.toLowerCase().contains(lowercaseQuery) ||
             (p.sku?.toLowerCase().contains(lowercaseQuery) ?? false) ||
             (p.barcode?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Deletes a product by ID.
  Future<void> deleteProduct(String id) async {
    final result = await _repository.delete(id);
    result.fold(
      (success) => loadProducts(),
      (failure) => state = state.copyWith(errorMessage: failure.message),
    );
  }
}

/// Provider for the ProductController.
final productControllerProvider = StateNotifierProvider<ProductController, ProductState>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductController(repository);
});
