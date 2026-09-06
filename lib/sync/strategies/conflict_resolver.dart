
/// Strategy for resolving data conflicts between local and remote storage.
abstract class ConflictResolver {
  /// Resolves a conflict and returns the final data to be persisted.
  /// 
  /// [localData] - Current data in SQLite.
  /// [remoteData] - Current data in PostgreSQL/Server.
  Future<Map<String, dynamic>> resolve(
    String entityName,
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
  );
}

/// Default implementation: The last update wins based on 'updatedAt' timestamp.
class LastWriteWinsResolver implements ConflictResolver {
  @override
  Future<Map<String, dynamic>> resolve(
    String entityName,
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
  ) async {
    final localUpdatedAt = DateTime.parse(localData['updatedAt'] ?? localData['updated_at']);
    final remoteUpdatedAt = DateTime.parse(remoteData['updatedAt'] ?? remoteData['updated_at']);

    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return localData;
    }
    return remoteData;
  }
}
