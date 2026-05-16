import 'emergency_service.dart';

/// Central entry for ML, debug, or manual SOS triggers.
class SosTriggerController {
  SosTriggerController._();
  static final SosTriggerController instance = SosTriggerController._();

  bool _triggering = false;

  Future<void> trigger(String reason) async {
    if (_triggering) return;
    _triggering = true;
    try {
      await EmergencyService.instance.startEmergency(reason: reason);
    } finally {
      _triggering = false;
    }
  }
}
