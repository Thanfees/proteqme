import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationSnapshot {
  const LocationSnapshot({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  String get mapsLink => 'https://maps.google.com/?q=$latitude,$longitude';
}

class LocationDatasource {
  const LocationDatasource();

  Future<bool> ensureReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LocationSnapshot?> getCurrentOrLastKnown() async {
    final ready = await ensureReady();
    if (!ready) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (position.latitude == 0 && position.longitude == 0) {
        return _lastKnown();
      }
      return LocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return _lastKnown();
    }
  }

  Future<LocationSnapshot?> _lastKnown() async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown == null) {
      return null;
    }
    return LocationSnapshot(
      latitude: lastKnown.latitude,
      longitude: lastKnown.longitude,
    );
  }
}

final locationDatasourceProvider = Provider<LocationDatasource>(
  (ref) => const LocationDatasource(),
);
