import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../data/local/app_database.dart';
import 'emergency_orchestrator.dart';

EmergencyOrchestrator? _orchestrator;

@pragma('vm:entry-point')
void onBackgroundStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await AppDatabase.instance.database;

  _orchestrator = EmergencyOrchestrator();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'ProteqMe Emergency',
      content: 'SOS active — alerts and location running',
    );
  }

  service.on('start_sos').listen((event) async {
    final reason = event?['reason'] as String? ?? 'service';
    await _orchestrator?.start(reason: reason);
  });

  service.on('disarm').listen((event) async {
    await _orchestrator?.disarm();
    if (service is AndroidServiceInstance) {
      await service.stopSelf();
    }
  });

  service.on('stop_monitoring').listen((event) async {
    if (service is AndroidServiceInstance) {
      await service.stopSelf();
    }
  });

  // Resume if already active when service starts (boot / relaunch).
  final db = await AppDatabase.instance.database;
  final rows = await db.query('sos_state', where: 'id = 1');
  if (rows.isNotEmpty && (rows.first['is_active'] as int? ?? 0) == 1) {
    await _orchestrator?.start(reason: 'resume');
  }
}
