import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../queue/sync_queue.dart';
import 'sync_engine.dart';
import 'sync_logger.dart';

/// The high-level manager that coordinates synchronization based on app lifecycle and connectivity.
/// 
/// It listens for network changes and triggers the [SyncEngine] to process the queue 
/// when the device comes back online.
class SyncManager {
  final SyncEngine _engine;
  final SyncQueue _queue;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncManager(this._engine, this._queue);

  /// Initializes the synchronization manager and starts listening for events.
  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  /// Manually triggers a synchronization cycle.
  Future<void> syncNow() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      SyncLogger.logQueue(0); // Log that we are offline
      return;
    }
    
    await _engine.processQueue();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (!results.contains(ConnectivityResult.none)) {
      // Device is online, attempt to process the queue
      syncNow();
    }
  }

  /// Disposes of listeners and resources.
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
