import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/sos_repository.dart';
import '../services/convex_service.dart';

/// Drains `pending_sync` when online and SOS is inactive.
class ConvexSyncWorker {
  ConvexSyncWorker({
    SosRepository? sosRepository,
    ConvexService? convexService,
    Connectivity? connectivity,
  })  : _sos = sosRepository ?? SosRepository(),
        _convex = convexService ?? ConvexService.instance,
        _connectivity = connectivity ?? Connectivity();

  final SosRepository _sos;
  final ConvexService _convex;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  static const _userIdKey = 'convex_user_id';

  Future<void> start() async {
    _sub?.cancel();
    _sub = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(syncPending());
    });
    await syncPending();
  }

  void dispose() => _sub?.cancel();

  Future<void> syncPending() async {
    if (!_convex.isConfigured) return;
    if (await _sos.isActive()) return;

    final results = await _connectivity.checkConnectivity();
    if (results.every((r) => r == ConnectivityResult.none)) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey) ?? 'local_user';

    final pending = await _sos.getPendingSync();
    for (final row in pending) {
      if (row.payload['type'] == 'incident_complete' ||
          row.payload.containsKey('gpsPoints')) {
        try {
          await _convex.recordSosEvent({
            'userId': userId,
            'triggeredAt': row.payload['triggeredAt'] as int? ??
                DateTime.now().millisecondsSinceEpoch,
            'disarmedAt': row.payload['disarmedAt'] as int?,
            'gpsPoints': row.payload['gpsPoints'] ?? [],
            'callSummary': row.payload['callSummary'] ?? [],
            'deviceMeta': {'source': 'android'},
          });
          await _sos.deletePendingSync(row.id);
        } catch (_) {
          await _sos.incrementRetry(row.id);
        }
      } else if (row.payload['type'] == 'trigger') {
        // Keep trigger rows until incident_complete uploads.
        if (row.retryCount > 20) {
          await _sos.deletePendingSync(row.id);
        }
      }
    }
  }
}
