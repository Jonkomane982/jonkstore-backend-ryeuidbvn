import '../../core/network/api_client.dart';
import '../../core/domain/models/inventory.dart';
import '../../core/domain/models/inventory_transaction.dart';

/// Remote data source for Inventory and Stock operations.
class InventoryRemoteDataSource {
  final ApiClient _apiClient;

  InventoryRemoteDataSource(this._apiClient);

  Future<Inventory> updateInventory(Inventory inventory) async {
    final response = await _apiClient.put('/inventory/${inventory.id}', data: inventory.toJson());
    return Inventory.fromJson(response.data);
  }

  Future<Inventory?> getInventory(String productId, String branchId) async {
    final response = await _apiClient.get('/inventory', queryParameters: {
      'productId': productId,
      'branchId': branchId,
    });
    return response.data != null ? Inventory.fromJson(response.data) : null;
  }

  Future<List<Inventory>> getAllInventory() async {
    final response = await _apiClient.get('/inventory');
    final List data = response.data;
    return data.map((e) => Inventory.fromJson(e)).toList();
  }

  Future<InventoryTransaction> createTransaction(InventoryTransaction transaction) async {
    final response = await _apiClient.post('/inventory/transactions', data: transaction.toJson());
    return InventoryTransaction.fromJson(response.data);
  }

  Future<List<InventoryTransaction>> getTransactions(String productId) async {
    final response = await _apiClient.get('/inventory/transactions/$productId');
    final List data = response.data;
    return data.map((e) => InventoryTransaction.fromJson(e)).toList();
  }
}
