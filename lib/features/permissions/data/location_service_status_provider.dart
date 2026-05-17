import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Streams the live state of the device's system Location/GPS toggle.
///
/// Emits `true` when the OS location services are turned on and `false` when
/// they are turned off. The first value comes from a one-shot
/// `Geolocator.isLocationServiceEnabled()` call so the UI can leave the
/// "loading" state as soon as possible; subsequent values are forwarded from
/// `Geolocator.getServiceStatusStream()` which fires whenever the user
/// toggles GPS in Quick Settings (including while the app is backgrounded).
///
/// Any platform/plugin error (e.g. missing platform implementation during
/// tests) is swallowed and surfaced as `false` so the UI can degrade
/// gracefully instead of crashing.
Stream<bool> _locationServiceEnabledStream() async* {
  try {
    yield await Geolocator.isLocationServiceEnabled();
  } catch (_) {
    yield false;
  }

  try {
    await for (final status in Geolocator.getServiceStatusStream()) {
      yield status == ServiceStatus.enabled;
    }
  } catch (_) {
    yield false;
  }
}

final locationServiceEnabledProvider = StreamProvider<bool>((ref) {
  return _locationServiceEnabledStream();
});
