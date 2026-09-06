import '../core/domain/models/settings.dart';
import '../core/network/result.dart';

/// Interface for Settings repository operations.
abstract class SettingsRepository {
  Future<Result<Settings>> update(Settings settings);
  Future<Result<Settings?>> getSettings(String businessId);
  
  Stream<Settings?> watchSettings(String businessId);
  Future<Result<void>> sync();
}
