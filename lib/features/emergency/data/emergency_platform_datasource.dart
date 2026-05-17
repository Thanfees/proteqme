import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';

class EmergencyPlatformDatasource {
  EmergencyPlatformDatasource();

  static const MethodChannel _channel = MethodChannel(
    AppConstants.serviceMethodChannel,
  );

  Future<bool> makeEmergencyCall(String phoneNumber) async {
    final result = await _channel.invokeMethod<bool>('makeEmergencyCall', {
      'phoneNumber': phoneNumber,
    });
    return result ?? false;
  }

  Future<bool> sendEmergencySms({
    required List<String> numbers,
    required String message,
  }) async {
    final result = await _channel.invokeMethod<bool>('sendEmergencySms', {
      'numbers': numbers,
      'message': message,
    });
    return result ?? false;
  }

  Future<Map<String, dynamic>> triggerEmergencyWorkflow({
    required String primaryNumber,
    required List<String> allNumbers,
    required String message,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'triggerEmergencyWorkflow',
      {
        'primaryNumber': primaryNumber,
        'allNumbers': allNumbers,
        'message': message,
      },
    );
    return raw ?? const <String, dynamic>{};
  }
}

final emergencyPlatformDatasourceProvider =
    Provider<EmergencyPlatformDatasource>(
      (ref) => EmergencyPlatformDatasource(),
    );
