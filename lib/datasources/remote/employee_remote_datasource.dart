import '../../core/network/api_client.dart';
import '../../core/domain/models/employee.dart';

/// Remote data source for Employee operations.
class EmployeeRemoteDataSource {
  final ApiClient _apiClient;

  EmployeeRemoteDataSource(this._apiClient);

  Future<Employee> create(Employee employee) async {
    final response = await _apiClient.post('/employees', data: employee.toJson());
    return Employee.fromJson(response.data);
  }

  Future<Employee> update(Employee employee) async {
    final response = await _apiClient.put('/employees/${employee.id}', data: employee.toJson());
    return Employee.fromJson(response.data);
  }

  Future<void> delete(String id) async {
    await _apiClient.delete('/employees/$id');
  }

  Future<Employee?> findById(String id) async {
    final response = await _apiClient.get('/employees/$id');
    return response.data != null ? Employee.fromJson(response.data) : null;
  }

  Future<List<Employee>> findAll() async {
    final response = await _apiClient.get('/employees');
    final List data = response.data;
    return data.map((e) => Employee.fromJson(e)).toList();
  }
}
