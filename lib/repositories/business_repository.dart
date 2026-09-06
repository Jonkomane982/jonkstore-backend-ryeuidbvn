import 'package:sqflite/sqflite.dart';
import '../core/domain/models/business.dart';
import '../core/network/result.dart';

/// Interface for Business repository operations.
abstract class BusinessRepository {
  Future<Result<Business>> create(Business business, {Transaction? txn});
  Future<Result<Business>> update(Business business);
  Future<Result<bool>> delete(String id);
  Future<Result<Business?>> findById(String id);
  Future<Result<List<Business>>> findAll();
  Future<Result<int>> count();
  Future<Result<bool>> exists(String id);
  Stream<List<Business>> watchAll();
  Future<Result<void>> sync();
}
