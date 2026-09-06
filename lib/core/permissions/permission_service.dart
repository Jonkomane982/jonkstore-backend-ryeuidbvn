import 'package:permission_handler/permission_handler.dart';
import '../logger/app_logger.dart';

/// Service to handle system permissions for JonkStore POS.
class PermissionService {
  /// Requests camera permission.
  Future<bool> requestCamera() async {
    return await _requestPermission(Permission.camera);
  }

  /// Requests storage/photos permission.
  Future<bool> requestStorage() async {
    return await _requestPermission(Permission.storage);
  }

  /// Requests location permission.
  Future<bool> requestLocation() async {
    return await _requestPermission(Permission.location);
  }

  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
    if (status.isGranted) {
      return true;
    } else {
      AppLogger.warning('Permission ${permission.toString()} denied');
      return false;
    }
  }

  /// Checks if a permission is granted.
  Future<bool> isGranted(Permission permission) async {
    return await permission.isGranted;
  }

  /// Opens app settings.
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
