import '../../core/network/api_client.dart';
import '../../core/domain/models/customer.dart';

/// Remote data source for Customer operations.
class CustomerRemoteDataSource {
  final ApiClient _apiClient;

  CustomerRemoteDataSource(this._apiClient);

  Future<Customer> create(Customer customer) async {
    final response = await _apiClient.post('/customers', data: customer.toJson());
    return Customer.fromJson(response.data);
  }

  Future<Customer> update(Customer customer) async {
    final response = await _apiClient.put('/customers/${customer.id}', data: customer.toJson());
    return Customer.fromJson(response.data);
  }

  Future<void> delete(String id) async {
    await _apiClient.delete('/customers/$id');
  }

  Future<Customer?> findById(String id) async {
    final response = await _apiClient.get('/customers/$id');
    return response.data != null ? Customer.fromJson(response.data) : null;
  }

  Future<List<Customer>> findAll() async {
    final response = await _apiClient.get('/customers');
    final List data = response.data;
    return data.map((e) => Customer.fromJson(e)).toList();
  }
}
