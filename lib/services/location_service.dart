import 'package:geolocator/geolocator.dart';

import '../core/config/app_config.dart';

class LocationResult {
  const LocationResult({
    required this.lat,
    required this.lng,
    this.accuracy,
    required this.source,
  });

  final double lat;
  final double lng;
  final double? accuracy;
  final String source;
}

class LocationService {
  Future<LocationResult?> getCurrentOrLastKnown() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: AppConfig.gpsTimeoutSec),
        ),
      );
      return LocationResult(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        source: 'fresh',
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return null;
      return LocationResult(
        lat: last.latitude,
        lng: last.longitude,
        accuracy: last.accuracy,
        source: 'last_known',
      );
    }
  }
}
