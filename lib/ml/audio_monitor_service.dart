import '../background/sos_trigger_controller.dart';
import '../core/config/app_config.dart';
import 'scream_detector.dart';
import 'wake_word_detector.dart';

/// Listens for emergencies when not in SOS — all detectors stubbed via flags.
class AudioMonitorService {
  AudioMonitorService._();
  static final AudioMonitorService instance = AudioMonitorService._();

  WakeWordDetector? _porcupine;
  WakeWordDetector? _regional;
  ScreamDetector? _scream;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    if (AppConfig.kEnablePorcupine) {
      // PorcupineWakeWordDetector when assets exist.
      _porcupine = NoOpWakeWordDetector();
    } else {
      _porcupine = NoOpWakeWordDetector();
    }

    if (AppConfig.kEnableRegionalWake) {
      _regional = NoOpWakeWordDetector();
    }

    if (AppConfig.kEnableTfliteScream) {
      _scream = NoOpScreamDetector();
    } else {
      _scream = NoOpScreamDetector();
    }

    await _porcupine?.start(() => _onDetect('wake_word'));
    await _regional?.start(() => _onDetect('regional_wake'));
    await _scream?.start((score) {
      if (score > 0.85) _onDetect('scream');
    });
  }

  Future<void> stop() async {
    await _porcupine?.stop();
    await _regional?.stop();
    await _scream?.stop();
    _running = false;
  }

  void _onDetect(String reason) {
    SosTriggerController.instance.trigger(reason);
  }
}
