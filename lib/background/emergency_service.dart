import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/config/app_config.dart';
import '../data/repositories/sos_repository.dart';
import 'background_entrypoint.dart';

/// Foreground service wrapper — bridges UI isolate and orchestrator.
class EmergencyService {
  EmergencyService._();
  static final EmergencyService instance = EmergencyService._();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    const emergencyChannel = AndroidNotificationChannel(
      AppConfig.emergencyNotificationChannelId,
      'ProteqMe Emergency',
      description: 'Active SOS foreground service',
      importance: Importance.max,
    );
    const monitoringChannel = AndroidNotificationChannel(
      AppConfig.monitoringNotificationChannelId,
      'ProteqMe Monitoring',
      description: 'Background listening for emergencies',
      importance: Importance.low,
    );

    final plugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await plugin?.createNotificationChannel(emergencyChannel);
    await plugin?.createNotificationChannel(monitoringChannel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onBackgroundStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConfig.emergencyNotificationChannelId,
        initialNotificationTitle: AppConfig.foregroundServiceName,
        initialNotificationContent: 'ProteqMe is ready',
        foregroundServiceTypes: [
          AndroidForegroundType.microphone,
          AndroidForegroundType.location,
        ],
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  Future<void> startEmergency({required String reason}) async {
    await initialize();
    final sos = SosRepository();
    final state = await sos.getState();
    if (!state.isActive) {
      await sos.activate(
        userName: state.userName.isNotEmpty ? state.userName : 'ProteqMe User',
        smsIntervalSec: state.smsIntervalSec,
        triggerReason: reason,
      );
    }

    final running = await _service.isRunning();
    if (!running) {
      await _service.startService();
    }
    _service.invoke('start_sos', {'reason': reason});
  }

  Future<void> disarm() async {
    _service.invoke('disarm');
  }

  Future<void> resumeIfActive() async {
    final active = await SosRepository().isActive();
    if (!active) return;
    await startEmergency(reason: 'resume');
  }

  Future<bool> isRunning() => _service.isRunning();
}
