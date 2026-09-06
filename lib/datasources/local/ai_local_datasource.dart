import '../../database/database_service.dart';
import '../../core/domain/models/ai_recommendation.dart';
import '../../database/database_constants.dart';

/// Local data source for AI Recommendation operations using SQLite.
class AILocalDataSource {
  final DatabaseService _databaseService;

  AILocalDataSource(this._databaseService);

  Future<void> insert(AIRecommendation recommendation) async {
    final db = await _databaseService.database;
    await db.insert(DatabaseConstants.tableAIRecommendations, recommendation.toJson());
  }

  Future<void> update(AIRecommendation recommendation) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableAIRecommendations,
      recommendation.toJson(),
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [recommendation.id],
    );
  }

  Future<void> markAsApplied(String id) async {
    final db = await _databaseService.database;
    await db.update(
      DatabaseConstants.tableAIRecommendations,
      {'isApplied': 1},
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _databaseService.database;
    await db.delete(
      DatabaseConstants.tableAIRecommendations,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<AIRecommendation?> findById(String id) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableAIRecommendations,
      where: '${DatabaseConstants.columnId} = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? AIRecommendation.fromJson(results.first) : null;
  }

  Future<List<AIRecommendation>> findAll(String businessId) async {
    final db = await _databaseService.database;
    final results = await db.query(
      DatabaseConstants.tableAIRecommendations,
      where: 'businessId = ?',
      whereArgs: [businessId],
      orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
    );
    return results.map((e) => AIRecommendation.fromJson(e)).toList();
  }
}
