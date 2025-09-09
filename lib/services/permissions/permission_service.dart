import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();
  static final instance = PermissionService._();

  /// Ensures we have notification permission on Android 13+.
  /// On older Android / iOS, this returns true immediately (no runtime prompt needed here).
  Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;

    // `permission_handler` handles API level differences internally.
    final status = await Permission.notification.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    final req = await Permission.notification.request();

    if (req.isGranted || req.isLimited) {
      return true;
    }

    // If permanently denied, you could direct users to app settings:
    // if (req.isPermanentlyDenied) { openAppSettings(); }
    return false;
  }
}
