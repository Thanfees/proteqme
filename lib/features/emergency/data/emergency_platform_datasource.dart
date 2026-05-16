import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';

class EmergencyPlatformDatasource {
  EmergencyPlatformDatasource();

  static const MethodChannel _channel = MethodChannel(
    AppConstants.serviceMethodChannel,
  );

  Future<bool> makeEmergencyCall(String phoneNumber) async {
    if (Platform.isAndroid) {
      final result = await _channel.invokeMethod<bool>('makeEmergencyCall', {
        'phoneNumber': phoneNumber,
      });
      return result ?? false;
    }

    return openDialer(phoneNumber);
  }

  Future<bool> sendEmergencySms({
    required List<String> numbers,
    required String message,
  }) async {
    if (Platform.isAndroid) {
      final result = await _channel.invokeMethod<bool>('sendEmergencySms', {
        'numbers': numbers,
        'message': message,
      });
      return result ?? false;
    }

    return openSmsComposer(numbers: numbers, message: message);
  }

  Future<Map<String, dynamic>> triggerEmergencyWorkflow({
    required String primaryNumber,
    required List<String> allNumbers,
    required String message,
  }) async {
    if (Platform.isAndroid) {
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

    final smsSent = await openSmsComposer(
      numbers: allNumbers,
      message: message,
    );
    final callStarted = await openDialer(primaryNumber);
    return <String, dynamic>{
      'smsSent': smsSent,
      'callStarted': callStarted,
      'locationIncluded': message.contains('maps.google.com/?q='),
      'message': message,
    };
  }

  Future<bool> openDialer(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> openSmsComposer({
    required List<String> numbers,
    required String message,
  }) async {
    if (numbers.isEmpty) {
      return false;
    }

    final recipients = Platform.isAndroid
        ? numbers.join(';')
        : numbers.join(',');
    final uri = Uri(
      scheme: 'smsto',
      path: recipients,
      queryParameters: <String, String>{'body': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

final emergencyPlatformDatasourceProvider =
    Provider<EmergencyPlatformDatasource>(
      (ref) => EmergencyPlatformDatasource(),
    );
