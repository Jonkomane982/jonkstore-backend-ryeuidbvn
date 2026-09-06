import 'dart:async';
import 'sync_manager.dart';
import 'sync_logger.dart';

/// Responsible for scheduling periodic synchronization tasks.
/// 
/// In a production environment, this might use 'work_manager' for 
/// background tasks on Android/iOS, but this implementation provides 
/// the core scheduling logic.
class SyncScheduler {
  final SyncManager _syncManager;
  Timer? _timer;

  SyncScheduler(this._syncManager);

  /// Starts periodic synchronization every [interval].
  void start({Duration interval = const Duration(minutes: 15)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      SyncLogger.logQueue(0); // Logging heart-beat
      await _syncManager.syncNow();
    });
  }

  /// Stops the periodic synchronization.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
