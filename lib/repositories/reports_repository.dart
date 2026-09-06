import '../core/network/result.dart';
import '../database/dao/reports_dao.dart';

/// Interface for Business Intelligence and Reporting.
abstract class ReportsRepository {
  /// Fetches sales aggregated by category.
  Future<Result<List<CategorySalesData>>> getSalesByCategory(DateTime start, DateTime end);

  /// Fetches the top selling products.
  Future<Result<List<ProductSalesData>>> getTopSellingProducts(DateTime start, DateTime end, {int limit = 10});

  /// Fetches daily revenue for a trend chart.
  Future<Result<List<Map<String, dynamic>>>> getDailyRevenue(DateTime start, DateTime end);
}
