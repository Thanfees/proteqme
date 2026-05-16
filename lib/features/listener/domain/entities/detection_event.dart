enum DetectionEventType { helpDetected, windowReset, triggered, cooldown }

class DetectionEvent {
  const DetectionEvent({
    required this.type,
    required this.count,
    required this.timestamp,
    this.cooldownRemaining,
  });

  final DetectionEventType type;
  final int count;
  final DateTime timestamp;
  final int? cooldownRemaining;

  factory DetectionEvent.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] as String? ?? '').toUpperCase();

    final type = switch (rawType) {
      'HELP_DETECTED' => DetectionEventType.helpDetected,
      'WINDOW_RESET' => DetectionEventType.windowReset,
      'TRIGGERED' => DetectionEventType.triggered,
      'COOLDOWN' => DetectionEventType.cooldown,
      _ => DetectionEventType.helpDetected,
    };

    final timestampMs =
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    return DetectionEvent(
      type: type,
      count: map['count'] as int? ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      cooldownRemaining: map['cooldownRemaining'] as int?,
    );
  }

  String summary() {
    return switch (type) {
      DetectionEventType.helpDetected =>
        'Emergency audio detected (count: $count)',
      DetectionEventType.windowReset => 'Window reset',
      DetectionEventType.triggered => 'TRIGGERED: calling emergency contact',
      DetectionEventType.cooldown =>
        'Cooldown (${cooldownRemaining ?? 0}s remaining)',
    };
  }
}
