import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nearby_connections/nearby_connections.dart';

/// Offline mesh broadcast when cellular is unavailable during SOS.
class RescueModeService {
  RescueModeService();

  static const _strategy = Strategy.P2P_CLUSTER;
  static const _serviceId = 'com.proteqme.rescue';

  bool _advertising = false;

  Future<void> startIfOffline({required String userName}) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.mobile) ||
        connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.ethernet)) {
      return;
    }

    if (_advertising) return;

    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return;

    final payload = jsonEncode({
      'type': 'SOS_RESCUE',
      'userName': userName,
      'lat': position.latitude,
      'lng': position.longitude,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      await Nearby().startAdvertising(
        userName,
        _strategy,
        onConnectionInitiated: (id, info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, data) {},
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            Nearby().sendBytesPayload(
              id,
              utf8.encode(payload),
            );
          }
        },
        onDisconnected: (id) {},
        serviceId: _serviceId,
      );
      _advertising = true;
      debugPrint('Rescue mode advertising started');
    } catch (e) {
      debugPrint('Rescue mode failed: $e');
    }
  }

  Future<void> stop() async {
    if (!_advertising) return;
    try {
      await Nearby().stopAdvertising();
    } catch (_) {}
    _advertising = false;
  }
}

final rescueModeServiceProvider = Provider<RescueModeService>(
  (ref) => RescueModeService(),
);
