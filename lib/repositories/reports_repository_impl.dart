import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/database/dao/reports_dao.dart';
import 'reports_repository.dart';

/// Production implementation of [ReportsRepository].
class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsDao _reportsDao;

  ReportsRepositoryImpl(this._reportsDao);

  @override
  Future<Result<List<CategorySalesData>>> getSalesByCategory(DateTime start, DateTime end) async {
    try {
      final data = await _reportsDao.getSalesByCategory(start, end);
      return Result.success(data);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ProductSalesData>>> getTopSellingProducts(DateTime start, DateTime end, {int limit = 10}) async {
    try {
      final data = await _reportsDao.getTopSellingProducts(start, end, limit: limit);
      return Result.success(data);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getDailyRevenue(DateTime start, DateTime end) async {
    try {
      final data = await _reportsDao.getDailyRevenue(start, end);
      return Result.success(data);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }
}
