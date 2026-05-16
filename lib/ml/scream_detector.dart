/// Scream / distress audio classifier interface.
abstract class ScreamDetector {
  Future<void> start(void Function(double score) onScore);
  Future<void> stop();
}

class NoOpScreamDetector implements ScreamDetector {
  @override
  Future<void> start(void Function(double score) onScore) async {}

  @override
  Future<void> stop() async {}
}
