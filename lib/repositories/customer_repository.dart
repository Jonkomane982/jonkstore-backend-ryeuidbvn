import '../core/domain/models/customer.dart';
import '../core/network/result.dart';

/// Interface for Customer repository operations.
abstract class CustomerRepository {
  Future<Result<Customer>> create(Customer customer);
  Future<Result<Customer>> update(Customer customer);
  Future<Result<bool>> delete(String id);
  Future<Result<Customer?>> findById(String id);
  Future<Result<List<Customer>>> findAll();
  Future<Result<List<Customer>>> search(String query);
  Future<Result<int>> count();
  
  Stream<List<Customer>> watchAll();
  Future<Result<void>> sync();
}
