class SosState {
  const SosState({
    required this.isActive,
    this.triggeredAt,
    required this.userName,
    required this.smsIntervalSec,
    required this.callPaused,
  });

  final bool isActive;
  final DateTime? triggeredAt;
  final String userName;
  final int smsIntervalSec;
  final bool callPaused;

  factory SosState.fromMap(Map<String, Object?> map) {
    final triggeredMs = map['triggered_at'] as int?;
    return SosState(
      isActive: (map['is_active'] as int? ?? 0) == 1,
      triggeredAt:
          triggeredMs != null ? DateTime.fromMillisecondsSinceEpoch(triggeredMs) : null,
      userName: map['user_name'] as String? ?? '',
      smsIntervalSec: map['sms_interval_sec'] as int? ?? 360,
      callPaused: (map['call_paused'] as int? ?? 0) == 1,
    );
  }

  Map<String, Object?> toMap() => {
        'id': 1,
        'is_active': isActive ? 1 : 0,
        'triggered_at': triggeredAt?.millisecondsSinceEpoch,
        'user_name': userName,
        'sms_interval_sec': smsIntervalSec,
        'call_paused': callPaused ? 1 : 0,
      };

  static const inactive = SosState(
    isActive: false,
    userName: '',
    smsIntervalSec: 360,
    callPaused: false,
  );
}
