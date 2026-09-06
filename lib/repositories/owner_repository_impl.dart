import 'package:sqflite/sqflite.dart';
import 'package:jonkstore/core/domain/models/owner_profile.dart';
import 'package:jonkstore/core/errors/failures.dart';
import 'package:jonkstore/core/network/result.dart';
import 'package:jonkstore/datasources/local/owner_local_datasource.dart';
import 'owner_repository.dart';

/// Implementation of [OwnerRepository] using SQLite for local persistence.
class OwnerRepositoryImpl implements OwnerRepository {
  final OwnerLocalDataSource _localDataSource;

  OwnerRepositoryImpl(this._localDataSource);

  @override
  Future<Result<void>> saveProfile(
    OwnerProfile profile, {
    Transaction? txn,
  }) async {
    try {
      await _localDataSource.saveProfile(profile, txn: txn);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<OwnerProfile?>> getProfile() async {
    try {
      final profile = await _localDataSource.getProfile();
      return Result.success(profile);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateVerificationStatus(bool isVerified) async {
    try {
      await _localDataSource.updateVerificationStatus(isVerified);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updatePasswordHash(String passwordHash) async {
    try {
      await _localDataSource.updatePasswordHash(passwordHash);
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteProfile() async {
    try {
      await _localDataSource.deleteProfile();
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }
}
