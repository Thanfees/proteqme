import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/permission_handler_repository.dart';
import '../domain/permission_repository.dart';
import '../domain/permission_state.dart';

class PermissionController extends Notifier<PermissionState> {
  late final PermissionRepository _repository;

  @override
  PermissionState build() {
    _repository = ref.read(permissionRepositoryProvider);
    Future<void>.microtask(refresh);
    return const PermissionState.initial();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      final status = await _repository.getStatus();
      state = status;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to read permission status: $error',
      );
    }
  }

  Future<void> requestMicrophone() async {
    await _request(_repository.requestMicrophone);
  }

  Future<void> requestCall() async {
    await _request(_repository.requestCall);
  }

  Future<void> requestSms() async {
    await _request(_repository.requestSms);
  }

  Future<void> requestLocation() async {
    await _request(_repository.requestLocation);
  }

  Future<void> requestNotifications() async {
    await _request(_repository.requestNotifications);
  }

  Future<void> openSettings() async {
    await _repository.openSettings();
  }

  Future<void> _request(Future<PermissionState> Function() action) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      state = await action();
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: 'Permission request failed: $error',
      );
    }
  }
}

final permissionControllerProvider =
    NotifierProvider<PermissionController, PermissionState>(
      PermissionController.new,
    );
