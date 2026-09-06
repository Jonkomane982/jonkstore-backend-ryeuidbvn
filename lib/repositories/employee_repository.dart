import '../core/domain/models/employee.dart';
import '../core/network/result.dart';

/// Interface for Employee repository operations.
abstract class EmployeeRepository {
  Future<Result<Employee>> create(Employee employee);
  Future<Result<Employee>> update(Employee employee);
  Future<Result<bool>> delete(String id);
  Future<Result<Employee?>> findById(String id);
  Future<Result<List<Employee>>> findAll();
  Future<Result<List<Employee>>> findByBranch(String branchId);
  
  Stream<List<Employee>> watchAll();
  Future<Result<void>> sync();
}
