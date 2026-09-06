import '../../core/network/api_client.dart';
import '../../core/domain/models/purchase_order.dart';
import '../../core/domain/models/purchase_order_item.dart';

/// Remote data source for Purchase Order operations.
class PurchaseRemoteDataSource {
  final ApiClient _apiClient;

  PurchaseRemoteDataSource(this._apiClient);

  Future<PurchaseOrder> createOrder(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    final response = await _apiClient.post('/purchases', data: {
      'order': order.toJson(),
      'items': items.map((e) => e.toJson()).toList(),
    });
    return PurchaseOrder.fromJson(response.data);
  }

  Future<PurchaseOrder> updateStatus(String orderId, String status) async {
    final response = await _apiClient.put('/purchases/$orderId/status', data: {'status': status});
    return PurchaseOrder.fromJson(response.data);
  }

  Future<PurchaseOrder?> getOrder(String id) async {
    final response = await _apiClient.get('/purchases/$id');
    return response.data != null ? PurchaseOrder.fromJson(response.data) : null;
  }

  Future<List<PurchaseOrder>> getAllOrders() async {
    final response = await _apiClient.get('/purchases');
    final List data = response.data;
    return data.map((e) => PurchaseOrder.fromJson(e)).toList();
  }
}
