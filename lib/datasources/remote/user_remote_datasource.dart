import '../../core/network/api_client.dart';
import '../../core/domain/models/user.dart';

/// Remote data source for User operations.
class UserRemoteDataSource {
  final ApiClient _apiClient;

  UserRemoteDataSource(this._apiClient);

  Future<User> createUser(User user) async {
    final response = await _apiClient.post('/users', data: user.toJson());
    return User.fromJson(response.data);
  }

  Future<User> updateUser(User user) async {
    final response = await _apiClient.put('/users/${user.id}', data: user.toJson());
    return User.fromJson(response.data);
  }

  Future<User?> getUser(String id) async {
    final response = await _apiClient.get('/users/$id');
    return response.data != null ? User.fromJson(response.data) : null;
  }

  Future<List<User>> getAllUsers() async {
    final response = await _apiClient.get('/users');
    final List data = response.data;
    return data.map((e) => User.fromJson(e)).toList();
  }
}
