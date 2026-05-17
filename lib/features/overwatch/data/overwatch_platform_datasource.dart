import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wire-format event names emitted by the native [OverwatchEventBus] over the
/// [OverwatchPlatformDatasource.events] channel.
class OverwatchEventType {
  const OverwatchEventType._();

  static const String tick = 'TICK';
  static const String expiringSoon = 'EXPIRING_SOON';
  static const String expired = 'EXPIRED';
  static const String cancelled = 'CANCELLED';
}

/// Thin wrapper around the `com.proteqme/overwatch` MethodChannel + the
/// `com.proteqme/overwatch/events` EventChannel.
///
/// Mirrors the contract documented in MainActivity.handleOverwatchCall:
///   * `start`   — arms two AlarmManager alarms (expiry + 60 s warning).
///   * `cancel`  — caller MUST have biometric-verified first; clears alarms +
///                 prefs.
///   * `getStatus` — returns `{active, remainingMs, destination, endAtMs,
///                 startAtMs}`.
class OverwatchPlatformDatasource {
  OverwatchPlatformDatasource();

  static const MethodChannel _methodChannel =
      MethodChannel('com.proteqme/overwatch');
  static const EventChannel _eventChannel =
      EventChannel('com.proteqme/overwatch/events');

  /// Arm the dead-man's switch on the native side.
  ///
  /// [userName], [primaryNumber] and [contactsJson] are stashed in
  /// `OverwatchPrefs` so the `OverwatchExpiredReceiver` can synthesise an
  /// EmergencyWorkflowExecutor call even if the app process is dead at expiry.
  Future<void> start({
    required int durationSeconds,
    required String destination,
    required String userName,
    required String primaryNumber,
    required String contactsJson,
  }) async {
    await _methodChannel.invokeMethod<void>('start', <String, dynamic>{
      'durationSeconds': durationSeconds,
      'destination': destination,
      'userName': userName,
      'primaryNumber': primaryNumber,
      'contactsJson': contactsJson,
    });
  }

  /// Cancel the timer.
  ///
  /// **Caller MUST have already biometric-verified.** This wrapper deliberately
  /// performs no auth so the UI layer is the single source of truth for who is
  /// allowed to stop the dead-man's switch.
  Future<void> cancel() async {
    await _methodChannel.invokeMethod<void>('cancel');
  }

  /// Returns `null` when no overwatch is active. The map mirrors the native
  /// payload: `{active: bool, remainingMs: int, destination: String?}` (plus
  /// `endAtMs` and `startAtMs` for diagnostics).
  Future<Map<String, dynamic>?> getStatus() async {
    final raw = await _methodChannel
        .invokeMapMethod<String, dynamic>('getStatus');
    if (raw == null) return null;
    final active = raw['active'] as bool? ?? false;
    if (!active) return null;
    return raw;
  }

  /// Broadcast stream of native lifecycle events. Use
  /// [OverwatchEventType] constants to match against the `type` key.
  Stream<Map<String, dynamic>> get events {
    return _eventChannel.receiveBroadcastStream().map((dynamic raw) {
      if (raw is Map) {
        return raw.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
      return <String, dynamic>{};
    });
  }
}

final overwatchPlatformDatasourceProvider =
    Provider<OverwatchPlatformDatasource>(
  (ref) => OverwatchPlatformDatasource(),
);
