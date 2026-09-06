import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/database/dao/dashboard_dao.dart';
import 'package:jonkstore/database/database_service.dart';
import 'package:jonkstore/database/database_constants.dart';
import 'package:jonkstore/features/dashboard/models/dashboard_data.dart';
import 'package:jonkstore/repositories/dashboard_repository.dart';
import 'package:jonkstore/core/domain/models/sale.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/models/notification.dart';
import 'package:jonkstore/core/domain/models/ai_recommendation.dart';

/// Production implementation of [DashboardRepository] using SQLite.
class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardDao _dashboardDao;
  final DatabaseService _databaseService;

  DashboardRepositoryImpl(this._dashboardDao, this._databaseService);

  @override
  Future<Result<DashboardData>> getDashboardData(String period) async {
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end = now;

      // Calculate date range based on period
      switch (period) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          start = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'month':
          start = DateTime(now.year, now.month, 1);
          break;
        default:
          start = DateTime(now.year, now.month, now.day);
      }

      // 1. Fetch Aggregate Summary
      final summary = await _dashboardDao.getSummary(start, end, period);

      // 2. Fetch Recent Sales
      final recentSales = await _getRecentSales(5);

      // 3. Fetch Low Stock Products
      final lowStockProducts = await _getLowStockProducts(5);

      // 4. Fetch Recent Notifications
      final recentNotifications = await _getRecentNotifications(3);

      // 5. Fetch Top AI Recommendation
      final topRecommendation = await _getTopRecommendation();

      // 6. Fetch Sync Queue Count
      final pendingSyncCount = await _getPendingSyncCount();

      // 7. Get Totals
      final totalProducts = await _getTotalCount(
        DatabaseConstants.tableProducts,
      );
      final totalCustomers = await _getTotalCount(
        DatabaseConstants.tableCustomers,
      );

      return Result.success(
        DashboardData(
          summary: summary,
          recentSales: recentSales,
          lowStockProducts: lowStockProducts,
          recentNotifications: recentNotifications,
          topRecommendation: topRecommendation,
          healthScore: _calculateHealthScore(summary),
          pendingSyncCount: pendingSyncCount,
          totalProducts: totalProducts,
          totalCustomers: totalCustomers,
        ),
      );
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  Future<List<Sale>> _getRecentSales(int limit) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableSales,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return results.map((e) => Sale.fromJson(e)).toList();
  }

  Future<List<Product>> _getLowStockProducts(int limit) async {
    final db = await _databaseService.database;
    final results = await db.rawQuery(
      '''
      SELECT p.* FROM ${DatabaseConstants.tableProducts} p
      JOIN ${DatabaseConstants.tableInventory} i ON p.id = i.productId
      WHERE i.quantity <= i.lowStockThreshold
      LIMIT ?
    ''',
      [limit],
    );
    return results.map((e) => Product.fromJson(e)).toList();
  }

  Future<List<Notification>> _getRecentNotifications(int limit) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableNotifications,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return results.map((e) => Notification.fromJson(e)).toList();
  }

  Future<AIRecommendation?> _getTopRecommendation() async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableAIRecommendations,
      orderBy: 'confidenceScore DESC',
      limit: 1,
    );
    if (results.isNotEmpty) {
      return AIRecommendation.fromJson(results.first);
    }
    return null;
  }

  Future<int> _getPendingSyncCount() async {
    final db = await _databaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableSyncQueue}',
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> _getTotalCount(String tableName) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName',
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }

  double _calculateHealthScore(dynamic summary) {
    // Real logic for health score based on revenue vs expenses, low stock, etc.
    if (summary.totalRevenue == 0) return 0.0;
    final margin = (summary.totalProfit / summary.totalRevenue);
    return margin.clamp(0.0, 1.0);
  }
}
