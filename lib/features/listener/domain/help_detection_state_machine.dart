enum HelpDetectionEventType { helpDetected, windowReset, triggered, cooldown }

class HelpDetectionEvent {
  const HelpDetectionEvent({
    required this.type,
    required this.count,
    required this.timestamp,
    this.cooldownRemaining,
  });

  final HelpDetectionEventType type;
  final int count;
  final DateTime timestamp;
  final int? cooldownRemaining;
}

class HelpDetectionStateMachine {
  HelpDetectionStateMachine({
    this.window = const Duration(seconds: 10),
    this.debounce = const Duration(seconds: 2),
    this.cooldown = const Duration(seconds: 60),
    this.confidenceThreshold = 0.55,
  });

  final Duration window;
  final Duration debounce;
  final Duration cooldown;
  final double confidenceThreshold;

  DateTime? _windowStart;
  DateTime? _lastDetection;
  DateTime? _cooldownUntil;
  int _count = 0;

  int get count => _count;

  int cooldownRemaining(DateTime now) {
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil == null || !cooldownUntil.isAfter(now)) {
      return 0;
    }

    final ms = cooldownUntil.difference(now).inMilliseconds;
    return ((ms + 999) / 1000).floor();
  }

  List<HelpDetectionEvent> process({
    required String transcript,
    required double? confidence,
    required DateTime at,
  }) {
    final events = <HelpDetectionEvent>[];

    if (_windowStart != null &&
        _count > 0 &&
        at.difference(_windowStart!).inMilliseconds > window.inMilliseconds) {
      _count = 0;
      _windowStart = null;
      events.add(
        HelpDetectionEvent(
          type: HelpDetectionEventType.windowReset,
          count: 0,
          timestamp: at,
        ),
      );
    }

    final cooldownSeconds = cooldownRemaining(at);
    if (cooldownSeconds > 0) {
      events.add(
        HelpDetectionEvent(
          type: HelpDetectionEventType.cooldown,
          count: _count,
          timestamp: at,
          cooldownRemaining: cooldownSeconds,
        ),
      );
      return events;
    }

    if (!_containsHelpToken(transcript)) {
      return events;
    }

    if (confidence != null && confidence < confidenceThreshold) {
      return events;
    }

    if (_lastDetection != null &&
        at.difference(_lastDetection!).inMilliseconds <
            debounce.inMilliseconds) {
      return events;
    }

    if (_count == 0) {
      _windowStart = at;
    }

    _count += 1;
    _lastDetection = at;

    events.add(
      HelpDetectionEvent(
        type: HelpDetectionEventType.helpDetected,
        count: _count,
        timestamp: at,
      ),
    );

    if (_count >= 3 &&
        _windowStart != null &&
        at.difference(_windowStart!).inMilliseconds <= window.inMilliseconds) {
      events.add(
        HelpDetectionEvent(
          type: HelpDetectionEventType.triggered,
          count: _count,
          timestamp: at,
        ),
      );

      _count = 0;
      _windowStart = null;
      _cooldownUntil = at.add(cooldown);

      events.add(
        HelpDetectionEvent(
          type: HelpDetectionEventType.cooldown,
          count: 0,
          timestamp: at,
          cooldownRemaining: cooldownRemaining(at),
        ),
      );
    }

    return events;
  }

  bool _containsHelpToken(String transcript) {
    return RegExp(r'\bhelp\b', caseSensitive: false).hasMatch(transcript);
  }
}
