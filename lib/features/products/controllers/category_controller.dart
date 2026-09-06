import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/category.dart';
import '../../../core/network/result.dart';
import '../../../repositories/category_repository.dart';
import '../../../providers/repository_providers.dart';
import 'package:uuid/uuid.dart';

/// State for the Category management module with pagination and soft-delete support.
class CategoryState {
  final List<Category> categories;
  final bool isLoading;
  final bool isLoadMoreLoading;
  final String? errorMessage;
  final String searchQuery;
  final String sortBy;
  final bool ascending;
  final bool includeDeleted;
  final int page;
  final int pageSize;
  final bool hasMore;

  CategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.isLoadMoreLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.sortBy = 'name',
    this.ascending = true,
    this.includeDeleted = false,
    this.page = 0,
    this.pageSize = 20,
    this.hasMore = true,
  });

  CategoryState copyWith({
    List<Category>? categories,
    bool? isLoading,
    bool? isLoadMoreLoading,
    String? errorMessage,
    String? searchQuery,
    String? sortBy,
    bool? ascending,
    bool? includeDeleted,
    int? page,
    int? pageSize,
    bool? hasMore,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isLoadMoreLoading: isLoadMoreLoading ?? this.isLoadMoreLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Controller for handling Category business logic, pagination, and persistence.
class CategoryController extends StateNotifier<CategoryState> {
  final CategoryRepository _repository;

  CategoryController(this._repository) : super(CategoryState()) {
    loadCategories();
  }

  /// Initial load or refresh.
  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, errorMessage: null, page: 0, hasMore: true);

    final result = await _repository.findAll(
      searchQuery: state.searchQuery,
      sortBy: state.sortBy,
      ascending: state.ascending,
      includeDeleted: state.includeDeleted,
      limit: state.pageSize,
      offset: 0,
    );

    result.fold(
      (categories) => state = state.copyWith(
        isLoading: false, 
        categories: categories,
        hasMore: categories.length == state.pageSize,
      ),
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
    );
  }

  /// Pagination: Load next page.
  Future<void> loadMore() async {
    if (state.isLoadMoreLoading || !state.hasMore) return;

    state = state.copyWith(isLoadMoreLoading: true);
    final nextPage = state.page + 1;
    final offset = nextPage * state.pageSize;

    final result = await _repository.findAll(
      searchQuery: state.searchQuery,
      sortBy: state.sortBy,
      ascending: state.ascending,
      includeDeleted: state.includeDeleted,
      limit: state.pageSize,
      offset: offset,
    );

    result.fold(
      (newCategories) {
        state = state.copyWith(
          isLoadMoreLoading: false,
          categories: [...state.categories, ...newCategories],
          page: nextPage,
          hasMore: newCategories.length == state.pageSize,
        );
      },
      (failure) => state = state.copyWith(isLoadMoreLoading: false),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadCategories();
  }

  void setSorting(String sortBy, bool ascending) {
    state = state.copyWith(sortBy: sortBy, ascending: ascending);
    loadCategories();
  }

  void setIncludeDeleted(bool value) {
    state = state.copyWith(includeDeleted: value);
    loadCategories();
  }

  Future<Result<Category>> createCategory({
    required String name,
    String? description,
    String? businessId,
  }) async {
    final category = Category(
      id: const Uuid().v4(),
      name: name,
      description: description,
      businessId: businessId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _repository.create(category);
    if (result.isSuccess) loadCategories();
    return result;
  }

  Future<Result<Category>> updateCategory(Category category) async {
    final result = await _repository.update(category);
    if (result.isSuccess) loadCategories();
    return result;
  }

  Future<Result<bool>> deleteCategory(String id) async {
    final result = await _repository.delete(id);
    if (result.isSuccess) loadCategories();
    return result;
  }

  Future<Result<bool>> restoreCategory(String id) async {
    final result = await _repository.restore(id);
    if (result.isSuccess) loadCategories();
    return result;
  }
}

final categoryControllerProvider = StateNotifierProvider<CategoryController, CategoryState>((ref) {
  return CategoryController(ref.watch(categoryRepositoryProvider));
});

final categoryStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  final activeCount = await repository.count(includeDeleted: false);
  final totalCount = await repository.count(includeDeleted: true);
  
  return {
    'active': activeCount.fold((c) => c, (f) => 0),
    'total': totalCount.fold((c) => c, (f) => 0),
  };
});
