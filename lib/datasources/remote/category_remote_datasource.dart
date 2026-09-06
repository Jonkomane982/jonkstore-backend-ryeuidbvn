import '../../core/network/api_client.dart';
import '../../core/domain/models/category.dart';

/// Remote data source for Category operations.
/// 
/// Communicates with the PostgreSQL cloud backend via the ApiClient.
class CategoryRemoteDataSource {
  final ApiClient _apiClient;

  CategoryRemoteDataSource(this._apiClient);

  /// Pushes a new category to the cloud.
  Future<Category> createCategory(Category category) async {
    final response = await _apiClient.post('/categories', data: category.toJson());
    return Category.fromJson(response.data);
  }

  /// Pushes an updated category to the cloud.
  Future<Category> updateCategory(Category category) async {
    final response = await _apiClient.put('/categories/${category.id}', data: category.toJson());
    return Category.fromJson(response.data);
  }

  /// Pushes a soft-delete status to the cloud.
  Future<void> deleteCategory(String id) async {
    await _apiClient.delete('/categories/$id');
  }

  /// Fetches all categories updated after a specific timestamp (for delta sync).
  Future<List<Category>> getUpdates(DateTime lastSync) async {
    final response = await _apiClient.get(
      '/categories/sync',
      queryParameters: {'last_sync': lastSync.toIso8601String()},
    );
    final List data = response.data;
    return data.map((e) => Category.fromJson(e)).toList();
  }
}
