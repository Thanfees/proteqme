import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/permission_repository.dart';
import '../domain/permission_state.dart';

class PermissionHandlerRepository implements PermissionRepository {
  @override
  Future<PermissionState> getStatus() async {
    final microphoneStatus = await Permission.microphone.status;

    final callStatus = Platform.isAndroid
        ? await Permission.phone.status
        : PermissionStatus.granted;

    final smsStatus = Platform.isAndroid
        ? await Permission.sms.status
        : PermissionStatus.granted;

    final notificationStatus = Platform.isAndroid
        ? await Permission.notification.status
        : PermissionStatus.granted;

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
    if (Platform.isAndroid) {
      await Permission.phone.request();
    }
    return getStatus();
  }

  @override
  Future<PermissionState> requestLocation() async {
    await Permission.locationWhenInUse.request();
    if (Platform.isAndroid) {
      await Permission.locationAlways.request();
    }
    return getStatus();
  }

  @override
  Future<PermissionState> requestMicrophone() async {
    await Permission.microphone.request();
    return getStatus();
  }

  @override
  Future<PermissionState> requestSms() async {
    if (Platform.isAndroid) {
      await Permission.sms.request();
    }
    return getStatus();
  }

  @override
  Future<PermissionState> requestNotifications() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
    return getStatus();
  }
}

bool _statusGranted(PermissionStatus status) {
  return status.isGranted || status.isLimited;
}

Future<bool> _locationGrantedNow() async {
  final whenInUse = await Permission.locationWhenInUse.status;
  if (_statusGranted(whenInUse)) return true;
  final always = await Permission.locationAlways.status;
  return always.isGranted;
}

final permissionRepositoryProvider = Provider<PermissionRepository>(
  (ref) => PermissionHandlerRepository(),
);
