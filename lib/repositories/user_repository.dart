import '../core/domain/models/user.dart';
import '../core/network/result.dart';

/// Interface for User repository operations.
abstract class UserRepository {
  Future<Result<User>> create(User user);
  Future<Result<User>> update(User user);
  Future<Result<bool>> delete(String id);
  Future<Result<User?>> findById(String id);
  Future<Result<List<User>>> findAll();
  Future<Result<List<User>>> search(String query);
  Future<Result<int>> count();
  Future<Result<bool>> exists(String id);
  Stream<List<User>> watchAll();
  Future<Result<void>> sync();
}
