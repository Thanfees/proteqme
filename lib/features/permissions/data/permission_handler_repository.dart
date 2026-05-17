import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/permission_repository.dart';
import '../domain/permission_state.dart';

class PermissionHandlerRepository implements PermissionRepository {
  @override
  Future<PermissionState> getStatus() async {
    final microphoneStatus = await Permission.microphone.status;
    final callStatus = await Permission.phone.status;
    final smsStatus = await Permission.sms.status;
    final notificationStatus = await Permission.notification.status;

    return PermissionState(
      microphoneGranted: microphoneStatus.isGranted,
      callGranted: callStatus.isGranted,
      smsGranted: smsStatus.isGranted,
      locationGranted: await _locationGrantedNow(),
      notificationGranted: notificationStatus.isGranted,
      loading: false,
    );
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }

  @override
  Future<PermissionState> requestCall() async {
    await Permission.phone.request();
    return getStatus();
  }

  @override
  Future<PermissionState> requestLocation() async {
    await Permission.locationWhenInUse.request();
    await Permission.locationAlways.request();
    return getStatus();
  }

  @override
  Future<PermissionState> requestMicrophone() async {
    await Permission.microphone.request();
    return getStatus();
  }

  @override
  Future<PermissionState> requestSms() async {
    await Permission.sms.request();
    return getStatus();
  }

  @override
  Future<PermissionState> requestNotifications() async {
    await Permission.notification.request();
    return getStatus();
  }
}

Future<bool> _locationGrantedNow() async {
  final whenInUse = await Permission.locationWhenInUse.status;
  if (whenInUse.isGranted || whenInUse.isLimited) return true;
  final always = await Permission.locationAlways.status;
  return always.isGranted;
}

final permissionRepositoryProvider = Provider<PermissionRepository>(
  (ref) => PermissionHandlerRepository(),
);
