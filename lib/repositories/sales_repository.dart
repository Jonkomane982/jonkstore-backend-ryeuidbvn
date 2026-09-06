import '../core/domain/models/sale.dart';
import '../core/domain/models/sale_item.dart';
import '../core/network/result.dart';

/// Interface for Sales repository operations.
abstract class SalesRepository {
  Future<Result<Sale>> createSale(Sale sale, List<SaleItem> items);
  Future<Result<Sale?>> findById(String id);
  Future<Result<List<Sale>>> findAll();
  Future<Result<List<Sale>>> findByDateRange(DateTime start, DateTime end);
  Future<Result<List<SaleItem>>> getSaleItems(String saleId);
  Future<Result<void>> refundSale(String saleId);
  
  Stream<List<Sale>> watchRecentSales(int limit);
  Future<Result<void>> sync();
}
