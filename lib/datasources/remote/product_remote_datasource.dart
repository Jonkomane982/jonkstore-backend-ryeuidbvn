import '../../core/network/api_client.dart';
import '../../core/domain/models/product.dart';

/// Remote data source for Product operations.
/// 
/// Prepared for interaction with a Node.js REST API.
class ProductRemoteDataSource {
  final ApiClient _apiClient;

  ProductRemoteDataSource(this._apiClient);

  Future<Product> createProduct(Product product) async {
    final response = await _apiClient.post('/products', data: product.toJson());
    return Product.fromJson(response.data);
  }

  Future<Product> updateProduct(Product product) async {
    final response = await _apiClient.put('/products/${product.id}', data: product.toJson());
    return Product.fromJson(response.data);
  }

  Future<void> deleteProduct(String id) async {
    await _apiClient.delete('/products/$id');
  }

  Future<Product?> getProduct(String id) async {
    final response = await _apiClient.get('/products/$id');
    if (response.data != null) {
      return Product.fromJson(response.data);
    }
    return null;
  }

  Future<List<Product>> getAllProducts() async {
    final response = await _apiClient.get('/products');
    final List data = response.data;
    return data.map((e) => Product.fromJson(e)).toList();
  }
}
