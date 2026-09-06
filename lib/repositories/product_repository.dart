import '../core/domain/models/product.dart';
import '../core/network/result.dart';

/// Interface for Product repository operations.
abstract class ProductRepository {
  Future<Result<Product>> create(Product product);
  Future<Result<Product>> update(Product product);
  Future<Result<bool>> delete(String id);
  Future<Result<Product?>> findById(String id);
  
  /// Specialized lookup for barcode scanners.
  Future<Result<Product?>> findByBarcode(String barcode);

  Future<Result<List<Product>>> findAll();
  Future<Result<List<Product>>> search(String query);
  Future<Result<int>> count();
  Future<Result<bool>> exists(String id);
  
  /// Watches for changes in the product list (useful for reactive UI).
  Stream<List<Product>> watchAll();

  /// Synchronizes local product data with the remote server.
  Future<Result<void>> sync();
}
