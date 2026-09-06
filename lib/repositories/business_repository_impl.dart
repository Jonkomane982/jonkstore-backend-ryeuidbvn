import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../core/domain/models/business.dart';
import '../core/network/result.dart';
import '../core/errors/failures.dart';
import '../datasources/local/business_local_datasource.dart';
import '../datasources/remote/business_remote_datasource.dart';
import 'business_repository.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  final BusinessLocalDataSource localDataSource;
  final BusinessRemoteDataSource remoteDataSource;
  final _streamController = StreamController<List<Business>>.broadcast();

  BusinessRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Result<Business>> create(Business business, {Transaction? txn}) async {
    try {
      await localDataSource.insert(business, txn: txn);
      _refresh();
      return Result.success(business);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Business>> update(Business business) async {
    try {
      await localDataSource.update(business);
      _refresh();
      return Result.success(business);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<bool>> delete(String id) async {
    // Businesses are rarely deleted in this context
    return Result.success(true);
  }

  @override
  Future<Result<Business?>> findById(String id) async {
    try {
      final business = await localDataSource.findById(id);
      return Result.success(business);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<Business>>> findAll() async {
    try {
      final businesses = await localDataSource.findAll();
      return Result.success(businesses);
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
      final business = await localDataSource.findById(id);
      return Result.success(business != null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<Business>> watchAll() {
    _refresh();
    return _streamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh() async {
    final businesses = await localDataSource.findAll();
    _streamController.add(businesses);
  }
}
