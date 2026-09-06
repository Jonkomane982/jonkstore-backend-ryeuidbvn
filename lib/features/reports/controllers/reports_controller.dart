import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jonkstore/repositories/reports_repository.dart';
import 'package:jonkstore/database/dao/reports_dao.dart';
import 'package:jonkstore/providers/repository_providers.dart';

class ReportsState {
  final bool isLoading;
  final String? errorMessage;
  final List<CategorySalesData> categorySales;
  final List<ProductSalesData> topProducts;
  final List<Map<String, dynamic>> dailyRevenue;
  final DateTime startDate;
  final DateTime endDate;

  ReportsState({
    this.isLoading = false,
    this.errorMessage,
    this.categorySales = const [],
    this.topProducts = const [],
    this.dailyRevenue = const [],
    required this.startDate,
    required this.endDate,
  });

  ReportsState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<CategorySalesData>? categorySales,
    List<ProductSalesData>? topProducts,
    List<Map<String, dynamic>>? dailyRevenue,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ReportsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      categorySales: categorySales ?? this.categorySales,
      topProducts: topProducts ?? this.topProducts,
      dailyRevenue: dailyRevenue ?? this.dailyRevenue,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class ReportsController extends StateNotifier<ReportsState> {
  final ReportsRepository _repository;

  ReportsController(this._repository)
      : super(ReportsState(
          startDate: DateTime.now().subtract(const Duration(days: 7)),
          endDate: DateTime.now(),
        ));

  Future<void> loadReports() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final categoryResult = await _repository.getSalesByCategory(state.startDate, state.endDate);
    final productsResult = await _repository.getTopSellingProducts(state.startDate, state.endDate);
    final revenueResult = await _repository.getDailyRevenue(state.startDate, state.endDate);

    categoryResult.fold(
      (categories) {
        state = state.copyWith(categorySales: categories);
      },
      (failure) => state = state.copyWith(errorMessage: failure.message),
    );

    productsResult.fold(
      (products) {
        state = state.copyWith(topProducts: products);
      },
      (failure) => state = state.copyWith(errorMessage: failure.message),
    );

    revenueResult.fold(
      (revenue) {
        state = state.copyWith(dailyRevenue: revenue, isLoading: false);
      },
      (failure) => state = state.copyWith(errorMessage: failure.message, isLoading: false),
    );
  }

  void updateDateRange(DateTime start, DateTime end) {
    state = state.copyWith(startDate: start, endDate: end);
    loadReports();
  }
}

final reportsControllerProvider = StateNotifierProvider<ReportsController, ReportsState>((ref) {
  return ReportsController(ref.watch(reportsRepositoryProvider));
});
