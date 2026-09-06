import 'dart:async';
import '../core/domain/models/ai_recommendation.dart';
import '../core/network/result.dart';
import '../core/errors/failures.dart';
import '../datasources/local/ai_local_datasource.dart';
import '../datasources/remote/ai_remote_datasource.dart';
import 'ai_repository.dart';

/// Implementation of [AIRepository].
class AIRepositoryImpl implements AIRepository {
  final AILocalDataSource localDataSource;
  final AIRemoteDataSource remoteDataSource;
  final _streamController = StreamController<List<AIRecommendation>>.broadcast();

  AIRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Result<List<AIRecommendation>>> getRecommendations(String businessId) async {
    try {
      final recommendations = await localDataSource.findAll(businessId);
      return Result.success(recommendations);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> applyRecommendation(String id) async {
    try {
      // In a real app, this might involve calling remoteDataSource.applyRecommendation(id)
      // and then updating the local state.
      return Result.success(null);
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> dismissRecommendation(String id) async {
    try {
      await localDataSource.delete(id);
      // _refresh(businessId); // Need businessId to refresh
      return Result.success(null);
    } catch (e) {
      return Result.failure(DatabaseFailure(e.toString()));
    }
  }

  @override
  Stream<List<AIRecommendation>> watchRecommendations(String businessId) {
    _refresh(businessId);
    return _streamController.stream;
  }

  @override
  Future<Result<void>> sync() async {
    return Result.success(null);
  }

  void _refresh(String businessId) async {
    final recommendations = await localDataSource.findAll(businessId);
    _streamController.add(recommendations);
  }
}
