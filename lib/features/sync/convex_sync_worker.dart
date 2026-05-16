import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_database.dart';
import '../../services/convex_service.dart';

class ConvexSyncWorker {
  ConvexSyncWorker(this._convex, this._db);

  final ConvexService? _convex;
  final AppDatabase _db;

  Future<void> drainPending() async {
    final convex = _convex;
    if (convex == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final rows = await _db.db.query('pending_sync', orderBy: 'id ASC');
    for (final row in rows) {
      final payload = jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      try {
        await convex.recordSosEvent(payload);
        await _db.db.delete(
          'pending_sync',
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (_) {
        break;
      }
    }
  }
}

FutureProvider<ConvexSyncWorker> convexSyncWorkerFutureProvider =
    FutureProvider<ConvexSyncWorker>((ref) async {
  final db = await AppDatabase.instance();
  return ConvexSyncWorker(ref.watch(convexServiceProvider), db);
});
