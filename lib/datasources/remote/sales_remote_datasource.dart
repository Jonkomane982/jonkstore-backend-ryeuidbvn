import '../../core/network/api_client.dart';
import '../../core/domain/models/sale.dart';
import '../../core/domain/models/sale_item.dart';

/// Remote data source for Sales operations.
class SalesRemoteDataSource {
  final ApiClient _apiClient;

  SalesRemoteDataSource(this._apiClient);

  Future<Sale> createSale(Sale sale, List<SaleItem> items) async {
    final response = await _apiClient.post('/sales', data: {
      'sale': sale.toJson(),
      'items': items.map((e) => e.toJson()).toList(),
    });
    return Sale.fromJson(response.data);
  }

  Future<Sale?> getSale(String id) async {
    final response = await _apiClient.get('/sales/$id');
    return response.data != null ? Sale.fromJson(response.data) : null;
  }

  Future<List<Sale>> getSales() async {
    final response = await _apiClient.get('/sales');
    final List data = response.data;
    return data.map((e) => Sale.fromJson(e)).toList();
  }
}
