/// Lifecycle phases for the Safe Journey / Overwatch dead-man's switch.
///
/// * [idle]          — no timer running, the card shows the setup UI.
/// * [active]        — countdown in progress, > 60 s remaining.
/// * [expiringSoon]  — ≤ 60 s left, the card pulses + buzzes.
/// * [completed]     — user verified safely, brief success state before idle.
enum OverwatchPhase {
  idle,
  active,
  expiringSoon,
  completed,
}

/// Immutable snapshot of the Overwatch timer.
///
/// `totalSeconds` is the originally requested duration; `remainingSeconds` is
/// the live countdown derived from the native AlarmManager `endAtMs` (the
/// Flutter side just renders — native is the authoritative source).
class OverwatchState {
  const OverwatchState({
    required this.phase,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.destination,
    required this.startedAtMs,
  });

  const OverwatchState.idle()
      : phase = OverwatchPhase.idle,
        totalSeconds = 0,
        remainingSeconds = 0,
        destination = '',
        startedAtMs = 0;

  final OverwatchPhase phase;
  final int totalSeconds;
  final int remainingSeconds;
  final String destination;
  final int startedAtMs;

  bool get isActive =>
      phase == OverwatchPhase.active || phase == OverwatchPhase.expiringSoon;

  OverwatchState copyWith({
    OverwatchPhase? phase,
    int? totalSeconds,
    int? remainingSeconds,
    String? destination,
    int? startedAtMs,
  }) {
    return OverwatchState(
      phase: phase ?? this.phase,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      destination: destination ?? this.destination,
      startedAtMs: startedAtMs ?? this.startedAtMs,
    );
  }
}
