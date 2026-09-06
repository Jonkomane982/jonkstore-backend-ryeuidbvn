import '../../core/logger/app_logger.dart';

/// Specialized logger for synchronization events.
class SyncLogger {
  static void logStart(String entityName) {
    AppLogger.info('🔄 [SYNC START] - Entity: $entityName');
  }

  static void logSuccess(String entityName, String operation) {
    AppLogger.info('✅ [SYNC SUCCESS] - Entity: $entityName | Op: $operation');
  }

  static void logError(String entityName, String operation, dynamic error) {
    AppLogger.error('❌ [SYNC ERROR] - Entity: $entityName | Op: $operation | Error: $error');
  }

  static void logConflict(String entityName, String entityId) {
    AppLogger.warning('⚠️ [SYNC CONFLICT] - Entity: $entityName | ID: $entityId');
  }

  static void logQueue(int count) {
    AppLogger.debug('📋 [SYNC QUEUE] - Pending tasks: $count');
  }
}
