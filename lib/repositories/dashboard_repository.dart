import '../core/network/result.dart';
import '../features/dashboard/models/dashboard_data.dart';

/// Interface for Dashboard data operations.
abstract class DashboardRepository {
  /// Fetches aggregated dashboard data for the given period.
  Future<Result<DashboardData>> getDashboardData(String period);
}
