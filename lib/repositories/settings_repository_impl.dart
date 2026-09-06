import 'dart:async';
import '../core/domain/models/settings.dart';
import '../core/network/result.dart';
import '../core/errors/failures.dart';
import '../datasources/local/settings_local_datasource.dart';
import '../datasources/remote/settings_remote_datasource.dart';
import 'settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;
  final SettingsRemoteDataSource remoteDataSource;
  final _streamController = StreamController<Settings?>.broadcast();

  SettingsRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Result<Settings>> update(Settings settings) async {
    try {
      await localDataSource.update(settings);
      _refresh(settings.businessId);
      return Result.success(settings);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<Settings?>> getSettings(String businessId) async {
    try {
      final settings = await localDataSource.getSettings(businessId);
      return Result.success(settings);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<Settings?> watchSettings(String businessId) {
    _refresh(businessId);
    return _streamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh(String businessId) async {
    final settings = await localDataSource.getSettings(businessId);
    _streamController.add(settings);
  }
}
