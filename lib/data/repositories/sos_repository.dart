import 'dart:convert';

import '../local/app_database.dart';
import '../models/sos_state.dart';

class SosRepository {
  SosRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<SosState> getState() async {
    final db = await _database.database;
    final rows = await db.query('sos_state', where: 'id = 1');
    if (rows.isEmpty) return SosState.inactive;
    return SosState.fromMap(rows.first);
  }

  Future<bool> isActive() async {
    final state = await getState();
    return state.isActive;
  }

  Future<void> activate({
    required String userName,
    int? smsIntervalSec,
    String triggerReason = 'manual',
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'sos_state',
      {
        'is_active': 1,
        'triggered_at': now,
        'user_name': userName,
        'sms_interval_sec': smsIntervalSec ?? 360,
        'call_paused': 0,
      },
      where: 'id = 1',
    );
    await queueSyncPayload({
      'type': 'trigger',
      'triggeredAt': now,
      'reason': triggerReason,
    });
  }

  Future<void> setCallPaused(bool paused) async {
    final db = await _database.database;
    await db.update(
      'sos_state',
      {'call_paused': paused ? 1 : 0},
      where: 'id = 1',
    );
  }

  Future<void> updateSmsInterval(int seconds) async {
    final db = await _database.database;
    await db.update(
      'sos_state',
      {'sms_interval_sec': seconds},
      where: 'id = 1',
    );
  }

  Future<void> updateUserName(String name) async {
    final db = await _database.database;
    await db.update(
      'sos_state',
      {'user_name': name},
      where: 'id = 1',
    );
  }

  Future<void> deactivate() async {
    final db = await _database.database;
    await db.update(
      'sos_state',
      {
        'is_active': 0,
        'triggered_at': null,
        'call_paused': 0,
      },
      where: 'id = 1',
    );
  }

  Future<void> logGps({
    required double lat,
    required double lng,
    double? accuracy,
    required String source,
  }) async {
    final db = await _database.database;
    await db.insert('gps_log', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'source': source,
    });
  }

  Future<List<Map<String, Object?>>> getGpsLog() async {
    final db = await _database.database;
    return db.query('gps_log', orderBy: 'timestamp ASC');
  }

  Future<void> logCall({
    int? contactId,
    required DateTime startedAt,
    DateTime? endedAt,
    int? durationSec,
    required String outcome,
  }) async {
    final db = await _database.database;
    await db.insert('call_log', {
      'contact_id': contactId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'duration_sec': durationSec,
      'outcome': outcome,
    });
  }

  Future<List<Map<String, Object?>>> getCallLog() async {
    final db = await _database.database;
    return db.query('call_log', orderBy: 'started_at ASC');
  }

  Future<void> queueSyncPayload(Map<String, dynamic> payload) async {
    final db = await _database.database;
    await db.insert('pending_sync', {
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
  }

  Future<List<PendingSyncRow>> getPendingSync() async {
    final db = await _database.database;
    final rows = await db.query('pending_sync', orderBy: 'created_at ASC');
    return rows
        .map(
          (r) => PendingSyncRow(
            id: r['id'] as int,
            payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            retryCount: r['retry_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<void> deletePendingSync(int id) async {
    final db = await _database.database;
    await db.delete('pending_sync', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(int id) async {
    final db = await _database.database;
    await db.rawUpdate(
      'UPDATE pending_sync SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<Map<String, dynamic>> buildIncidentPayload() async {
    final state = await getState();
    final gps = await getGpsLog();
    final calls = await getCallLog();
    return {
      'triggeredAt': state.triggeredAt?.millisecondsSinceEpoch,
      'disarmedAt': DateTime.now().millisecondsSinceEpoch,
      'userName': state.userName,
      'gpsPoints': gps
          .map(
            (g) => {
              'timestamp': g['timestamp'],
              'lat': g['lat'],
              'lng': g['lng'],
              'accuracy': g['accuracy'],
              'source': g['source'],
            },
          )
          .toList(),
      'callSummary': calls
          .map(
            (c) => {
              'contactId': c['contact_id'],
              'startedAt': c['started_at'],
              'endedAt': c['ended_at'],
              'durationSec': c['duration_sec'],
              'outcome': c['outcome'],
            },
          )
          .toList(),
    };
  }

  Future<void> clearIncidentLogs() async {
    final db = await _database.database;
    await db.delete('gps_log');
    await db.delete('call_log');
  }
}

class PendingSyncRow {
  const PendingSyncRow({
    required this.id,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
  });

  final int id;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
}
