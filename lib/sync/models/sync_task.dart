import 'sync_state.dart';

/// Represents a single synchronization operation in the queue.
class SyncTask {
  final String id;
  final String entityName;
  final String entityId;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final Map<String, dynamic> data;
  final SyncState state;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;

  SyncTask({
    required this.id,
    required this.entityName,
    required this.entityId,
    required this.operation,
    required this.data,
    this.state = SyncState.pending,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
  });

  SyncTask copyWith({
    SyncState? state,
    int? retryCount,
    String? lastError,
  }) {
    return SyncTask(
      id: id,
      entityName: entityName,
      entityId: entityId,
      operation: operation,
      data: data,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityName': entityName,
      'entityId': entityId,
      'operation': operation,
      'data': data,
      'state': state.name,
      'retryCount': retryCount,
      'lastError': lastError,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
