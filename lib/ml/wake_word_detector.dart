/// Wake-word detector interface — swap Porcupine / regional models when ready.
abstract class WakeWordDetector {
  Future<void> start(void Function() onDetected);
  Future<void> stop();
}

class NoOpWakeWordDetector implements WakeWordDetector {
  @override
  Future<void> start(void Function() onDetected) async {}

  @override
  Future<void> stop() async {}
}
