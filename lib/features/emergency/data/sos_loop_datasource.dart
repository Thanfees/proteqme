import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../contacts/domain/entities/emergency_contact.dart';

class SosLoopDatasource {
  SosLoopDatasource();

  static const _channel = MethodChannel(AppConstants.serviceMethodChannel);

  Future<void> startLoop({
    required String userName,
    required List<EmergencyContact> contacts,
    int smsIntervalSec = 360,
  }) async {
    if (!Platform.isAndroid) return;

    final payload =
        contacts.asMap().entries.map((entry) {
          final c = entry.value;
          return {
            'phone': c.phone,
            'name': c.name,
            'priority': entry.key + 1,
            'language': c.language,
          };
        }).toList();

    await _channel.invokeMethod<void>('startSosLoop', {
      'userName': userName,
      'smsIntervalSec': smsIntervalSec,
      'contactsJson': jsonEncode(payload),
    });
  }

  Future<void> disarm() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('disarmSosLoop');
  }

  Future<bool> isActive() async {
    if (!Platform.isAndroid) return false;
    final map = await _channel.invokeMapMethod<String, dynamic>('getSosLoopStatus');
    return map?['active'] as bool? ?? false;
  }
}
