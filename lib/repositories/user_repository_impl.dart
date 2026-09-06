import 'dart:async';
import '../core/domain/models/user.dart';
import '../core/network/result.dart';
import '../core/errors/failures.dart';
import '../datasources/local/user_local_datasource.dart';
import '../datasources/remote/user_remote_datasource.dart';
import 'user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final UserLocalDataSource localDataSource;
  final UserRemoteDataSource remoteDataSource;
  final _streamController = StreamController<List<User>>.broadcast();

  UserRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Result<User>> create(User user) async {
    try {
      await localDataSource.insert(user);
      _refresh();
      return Result.success(user);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<User>> update(User user) async {
    try {
      await localDataSource.update(user);
      _refresh();
      return Result.success(user);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> delete(String id) async {
    try {
      await localDataSource.delete(id);
      _refresh();
      return Result.success(true);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<User?>> findById(String id) async {
    try {
      final user = await localDataSource.findById(id);
      return Result.success(user);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<User>>> findAll() async {
    try {
      final users = await localDataSource.findAll();
      return Result.success(users);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<User>>> search(String query) async {
    try {
      // Basic local filter for now
      final all = await localDataSource.findAll();
      final filtered = all.where((u) => u.name.contains(query) || u.email.contains(query)).toList();
      return Result.success(filtered);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<int>> count() async {
    try {
      final all = await localDataSource.findAll();
      return Result.success(all.length);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> exists(String id) async {
    try {
      final user = await localDataSource.findById(id);
      return Result.success(user != null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<User>> watchAll() {
    _refresh();
    return _streamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh() async {
    final users = await localDataSource.findAll();
    _streamController.add(users);
  }
}
