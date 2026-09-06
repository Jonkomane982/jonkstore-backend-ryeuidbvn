import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/core_providers.dart';
import '../engine/sync_engine.dart';
import '../engine/sync_manager.dart';
import '../engine/sync_scheduler.dart';
import '../engine/sync_worker_registry.dart';
import '../queue/sqlite_sync_queue.dart';
import '../queue/sync_queue.dart';
import '../strategies/conflict_resolver.dart';

/// Provider for the [SyncQueue] implementation.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  return SqliteSyncQueue(ref.watch(databaseServiceProvider));
});

/// Provider for the [ConflictResolver] strategy.
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return LastWriteWinsResolver();
});

/// Provider for the [SyncWorkerRegistry].
final syncWorkerRegistryProvider = Provider<SyncWorkerRegistry>((ref) {
  return SyncWorkerRegistry();
});

/// Provider for the [SyncEngine].
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    ref.watch(syncQueueProvider),
    ref.watch(conflictResolverProvider),
    ref.watch(syncWorkerRegistryProvider),
  );
});

/// Provider for the [SyncManager].
final syncManagerProvider = Provider<SyncManager>((ref) {
  return SyncManager(
    ref.watch(syncEngineProvider),
    ref.watch(syncQueueProvider),
  );
});

/// Provider for the [SyncScheduler].
final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  return SyncScheduler(ref.watch(syncManagerProvider));
});
