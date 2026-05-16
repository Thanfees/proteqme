import 'package:permission_handler/permission_handler.dart';

/// Runtime permission helpers for onboarding.
class PermissionFlow {
  PermissionFlow._();

  static Future<bool> requestEmergencyPermissions() async {
    final permissions = [
      Permission.sms,
      Permission.phone,
      Permission.location,
      Permission.locationAlways,
      Permission.microphone,
      Permission.notification,
    ];

    var allGranted = true;
    for (final p in permissions) {
      final status = await p.request();
      if (!status.isGranted && !status.isLimited) {
        allGranted = false;
      }
    }
    return allGranted;
  }

  static Future<void> openBatteryOptimizationSettings() async {
    await openAppSettings();
  }
}
