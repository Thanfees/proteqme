import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

/// A victim whose advertising was picked up by the rescuer's scan.
class DiscoveredVictim {
  const DiscoveredVictim({
    required this.endpointId,
    required this.userName,
    required this.lat,
    required this.lng,
    required this.discoveredAt,
  });

  final String endpointId;
  final String userName;
  final double lat;
  final double lng;
  final DateTime discoveredAt;

  String get mapsLink =>
      'https://maps.google.com/?q=$lat,$lng';
}

/// Handles both victim advertising and rescuer discovery for offline mesh rescue.
///
/// Victim flow  : SOS triggers → [startAdvertising] auto-called every time
/// Rescuer flow : Rescuer taps toggle → [startDiscovery] → [victims] stream
class RescueModeService {
  RescueModeService();

  static const _strategy = Strategy.P2P_CLUSTER;
  static const _serviceId = 'com.proteqme.rescue';

  bool _advertising = false;
  bool _discovering = false;

  final _victimsController =
      StreamController<List<DiscoveredVictim>>.broadcast();
  final _victims = <String, DiscoveredVictim>{};

  Stream<List<DiscoveredVictim>> get victims => _victimsController.stream;
  List<DiscoveredVictim> get currentVictims =>
      List.unmodifiable(_victims.values.toList());
  bool get isAdvertising => _advertising;
  bool get isDiscovering => _discovering;

  // ── Victim side ────────────────────────────────────────────────────────────

  /// Always start advertising when SOS is triggered so nearby rescuers
  /// (even with internet) can physically locate the victim.
  Future<void> startAdvertising({required String userName}) async {
    if (_advertising) return;

    if (!await _ensureRescuePermissions()) {
      debugPrint('RescueMode: Bluetooth permissions denied — skipping advertise');
      return;
    }

    Position? position = await Geolocator.getLastKnownPosition();
    position ??= await Geolocator.getCurrentPosition().then(
      (p) => p,
      onError: (_) => null,
    );
    if (position == null) {
      debugPrint('RescueMode: no GPS — skipping advertise');
      return;
    }

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
            Nearby().sendBytesPayload(id, utf8.encode(payload));
          }
        },
        onDisconnected: (_) {},
        serviceId: _serviceId,
      );
      _advertising = true;
      debugPrint('RescueMode: advertising started for $userName');
    } catch (e) {
      debugPrint('RescueMode: advertise failed: $e');
    }
  }

  Future<void> stopAdvertising() async {
    if (!_advertising) return;
    try {
      await Nearby().stopAdvertising();
    } catch (_) {}
    _advertising = false;
    debugPrint('RescueMode: advertising stopped');
  }

  // ── Rescuer side ────────────────────────────────────────────────────────────

  Future<void> startDiscovery() async {
    if (_discovering) return;
    if (!await _ensureRescuePermissions()) {
      debugPrint('RescueMode: Bluetooth permissions denied — cannot scan');
      return;
    }
    _victims.clear();
    _victimsController.add([]);

    try {
      await Nearby().startDiscovery(
        'Rescuer',
        _strategy,
        onEndpointFound: (id, name, serviceId) async {
          debugPrint('RescueMode: found endpoint $id $name');
          try {
            await Nearby().requestConnection(
              'Rescuer',
              id,
              onConnectionInitiated: (endId, info) async {
                await Nearby().acceptConnection(
                  endId,
                  onPayLoadRecieved: (endpointId, payload) {
                    if (payload.type == PayloadType.BYTES) {
                      _onPayload(endpointId, payload.bytes ?? []);
                    }
                  },
                );
              },
              onConnectionResult: (endId, status) {
                debugPrint('RescueMode: connect result $status');
              },
              onDisconnected: (endId) {
                _victims.remove(endId);
                _victimsController.add(currentVictims);
              },
            );
          } catch (e) {
            debugPrint('RescueMode: connect request failed: $e');
          }
        },
        onEndpointLost: (id) {
          if (id != null) {
            _victims.remove(id);
            _victimsController.add(currentVictims);
          }
        },
        serviceId: _serviceId,
      );
      _discovering = true;
      debugPrint('RescueMode: discovery started');
    } catch (e) {
      debugPrint('RescueMode: discovery failed: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (!_discovering) return;
    try {
      await Nearby().stopDiscovery();
    } catch (_) {}
    _discovering = false;
    debugPrint('RescueMode: discovery stopped');
  }

  void _onPayload(String endpointId, List<int> bytes) {
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (map['type'] != 'SOS_RESCUE') return;

      final victim = DiscoveredVictim(
        endpointId: endpointId,
        userName: map['userName'] as String? ?? 'Unknown',
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        discoveredAt: DateTime.now(),
      );
      _victims[endpointId] = victim;
      _victimsController.add(currentVictims);
    } catch (e) {
      debugPrint('RescueMode: bad payload: $e');
    }
  }

  /// Request runtime Bluetooth permissions (Android 12+ split them out).
  Future<bool> _ensureRescuePermissions() async {
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();

    return statuses[Permission.bluetoothAdvertise]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  }

  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
    await _victimsController.close();
  }
}

final rescueModeServiceProvider = Provider<RescueModeService>(
  (ref) {
    final service = RescueModeService();
    ref.onDispose(service.dispose);
    return service;
  },
);
