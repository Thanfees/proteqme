import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/local/app_database.dart';
import '../../../services/convex_service.dart';
import '../../../services/live_location_service.dart';
import '../../contacts/domain/entities/emergency_contact.dart';
import '../../rescue/rescue_mode_service.dart';
import '../domain/entities/emergency_event_log.dart';
import '../domain/entities/emergency_execution_result.dart';
import '../domain/entities/emergency_trigger_type.dart';
import '../domain/repositories/emergency_repository.dart';
import 'location_datasource.dart';
import 'sos_loop_datasource.dart';

class HiveEmergencyRepository implements EmergencyRepository {
  HiveEmergencyRepository({
    required Box<EmergencyEventLog> logsBox,
    required LocationDatasource locationDatasource,
    required SosLoopDatasource sosLoopDatasource,
    required RescueModeService rescueModeService,
  }) : _logsBox = logsBox,
       _locationDatasource = locationDatasource,
       _sosLoop = sosLoopDatasource,
       _rescue = rescueModeService;

  final Box<EmergencyEventLog> _logsBox;
  final LocationDatasource _locationDatasource;
  final SosLoopDatasource _sosLoop;
  final RescueModeService _rescue;

  @override
  Future<EmergencyExecutionResult> executeWorkflow({
    required EmergencyTriggerType triggerType,
    required String primaryNumber,
    required List<String> allNumbers,
    required List<EmergencyContact> contacts,
    required bool callPermissionGranted,
    required bool smsPermissionGranted,
    required bool locationPermissionGranted,
  }) async {
    final sorted =
        List<EmergencyContact>.from(contacts)
          ..sort((a, b) {
            if (a.isPrimary) return -1;
            if (b.isPrimary) return 1;
            return a.name.compareTo(b.name);
          });

    final location = locationPermissionGranted
        ? await _locationDatasource.getCurrentOrLastKnown()
        : null;
    final locationIncluded = location != null;

    if (location != null) {
      final db = await AppDatabase.instance();
      await db.appendGpsLog(
        lat: location.latitude,
        lng: location.longitude,
        source: 'trigger',
      );
    }

    var smsAttempted = false;
    var callAttempted = false;

    if (Platform.isAndroid && sorted.isNotEmpty) {
      await _sosLoop.startLoop(
        userName: 'ProteqMe User',
        contacts: sorted,
        smsIntervalSec: 360,
      );
      smsAttempted = true;
      callAttempted = callPermissionGranted;

      final db = await AppDatabase.instance();
      await db.setSosActive(active: true);

      await _rescue.startIfOffline(userName: 'ProteqMe User');

      final convex = ConvexService.tryCreate();
      if (convex != null) {
        final session = await db.db.query('auth_session', where: 'id = ?', whereArgs: [1]);
        final userId = session.first['user_id'] as String?;
        if (userId != null) {
          final live = LiveLocationService(convex, _locationDatasource, db);
          await live.start(userId);
        }
      }

      await db.queuePendingSync(
        jsonEncode({
          'triggerType': triggerType.value,
          'triggeredAtMs': DateTime.now().millisecondsSinceEpoch,
          'locationIncluded': locationIncluded,
        }),
      );
    } else {
      // iOS / fallback: one-shot composer flows only.
      smsAttempted = smsPermissionGranted && allNumbers.isNotEmpty;
      callAttempted = callPermissionGranted;
    }

    final log = EmergencyEventLog(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: triggerType.value,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      callAttempted: callAttempted,
      smsAttempted: smsAttempted,
      locationIncluded: locationIncluded,
    );

    await _logsBox.put(log.id, log);

    return EmergencyExecutionResult(
      callAttempted: callAttempted,
      smsAttempted: smsAttempted,
      locationIncluded: locationIncluded,
      message: location?.mapsLink ?? 'SOS loop started',
    );
  }

  @override
  Stream<List<EmergencyEventLog>> watchLogs() {
    return _logsBox.watch().map((_) => _sortedLogs()).startWith(_sortedLogs());
  }

  List<EmergencyEventLog> _sortedLogs() {
    final logs = _logsBox.values.toList(growable: false);
    logs.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return logs.take(AppConstants.emergencyLogLimit).toList(growable: false);
  }
}

final hiveEmergencyRepositoryProvider = Provider<HiveEmergencyRepository>(
  (ref) => HiveEmergencyRepository(
    logsBox: Hive.box<EmergencyEventLog>(AppConstants.emergencyLogsBoxName),
    locationDatasource: ref.watch(locationDatasourceProvider),
    sosLoopDatasource: SosLoopDatasource(),
    rescueModeService: ref.watch(rescueModeServiceProvider),
  ),
);

extension _StartWithExtension<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
