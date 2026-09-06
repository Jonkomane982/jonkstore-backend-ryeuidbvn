import 'package:jonkstore/core/domain/models/dashboard_summary.dart';
import 'package:jonkstore/core/domain/models/sale.dart';
import 'package:jonkstore/core/domain/models/product.dart';
import 'package:jonkstore/core/domain/models/notification.dart';
import 'package:jonkstore/core/domain/models/ai_recommendation.dart';

/// Aggregated data required for the Dashboard view.
class DashboardData {
  final DashboardSummary summary;
  final List<Sale> recentSales;
  final List<Product> lowStockProducts;
  final List<Notification> recentNotifications;
  final AIRecommendation? topRecommendation;
  final double healthScore;
  final int pendingSyncCount;
  final int totalProducts;
  final int totalCustomers;

  DashboardData({
    required this.summary,
    required this.recentSales,
    required this.lowStockProducts,
    required this.recentNotifications,
    this.topRecommendation,
    required this.healthScore,
    required this.pendingSyncCount,
    required this.totalProducts,
    required this.totalCustomers,
  });
}
