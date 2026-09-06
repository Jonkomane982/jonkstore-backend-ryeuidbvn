import '../../core/network/api_client.dart';
import '../../core/domain/models/supplier.dart';

/// Remote data source for Supplier operations.
class SupplierRemoteDataSource {
  final ApiClient _apiClient;

  SupplierRemoteDataSource(this._apiClient);

  Future<Supplier> create(Supplier supplier) async {
    final response = await _apiClient.post('/suppliers', data: supplier.toJson());
    return Supplier.fromJson(response.data);
  }

  Future<Supplier> update(Supplier supplier) async {
    final response = await _apiClient.put('/suppliers/${supplier.id}', data: supplier.toJson());
    return Supplier.fromJson(response.data);
  }

  Future<void> delete(String id) async {
    await _apiClient.delete('/suppliers/$id');
  }

  Future<Supplier?> findById(String id) async {
    final response = await _apiClient.get('/suppliers/$id');
    return response.data != null ? Supplier.fromJson(response.data) : null;
  }

  Future<List<Supplier>> findAll() async {
    final response = await _apiClient.get('/suppliers');
    final List data = response.data;
    return data.map((e) => Supplier.fromJson(e)).toList();
  }
}
