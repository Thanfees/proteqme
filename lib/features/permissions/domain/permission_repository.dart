import 'permission_state.dart';

abstract class PermissionRepository {
  Future<PermissionState> getStatus();

  Future<PermissionState> requestMicrophone();

  Future<PermissionState> requestCall();

  Future<PermissionState> requestSms();

  Future<PermissionState> requestLocation();

  Future<PermissionState> requestNotifications();

  Future<void> openSettings();
}
