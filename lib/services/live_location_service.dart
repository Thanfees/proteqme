import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../features/emergency/data/location_datasource.dart';
import 'convex_service.dart';

/// Pushes live GPS to Convex for family monitoring when online + SOS active.
class LiveLocationService {
  LiveLocationService(this._convex, this._location, this._db);

  final ConvexService? _convex;
  final LocationDatasource _location;
  final AppDatabase _db;

  Timer? _timer;

  Future<void> start(String userId) async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _tick(userId);
    });
    await _tick(userId);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick(String userId) async {
    final convex = _convex;
    if (convex == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final active = await _db.isSosActive();
    if (!active) {
      stop();
      return;
    }

    final loc = await _location.getCurrentOrLastKnown();
    if (loc == null) return;

    await _db.appendGpsLog(
      lat: loc.latitude,
      lng: loc.longitude,
      source: 'live_push',
    );

    await convex.pushLiveLocation(
      userId: userId,
      lat: loc.latitude,
      lng: loc.longitude,
      sosActive: true,
    );
  }
}

final liveLocationServiceProvider = Provider<LiveLocationService>((ref) {
  throw UnimplementedError('Use liveLocationServiceFutureProvider');
});

final liveLocationServiceFutureProvider =
    FutureProvider<LiveLocationService>((ref) async {
  final db = await AppDatabase.instance();
  return LiveLocationService(
    ref.watch(convexServiceProvider),
    ref.watch(locationDatasourceProvider),
    db,
  );
});
