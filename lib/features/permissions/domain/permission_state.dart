class PermissionState {
  const PermissionState({
    required this.microphoneGranted,
    required this.callGranted,
    required this.smsGranted,
    required this.locationGranted,
    required this.notificationGranted,
    required this.loading,
    this.error,
  });

  const PermissionState.initial()
    : microphoneGranted = false,
      callGranted = false,
      smsGranted = false,
      locationGranted = false,
      notificationGranted = false,
      loading = true,
      error = null;

  final bool microphoneGranted;
  final bool callGranted;
  final bool smsGranted;
  final bool locationGranted;
  final bool notificationGranted;
  final bool loading;
  final String? error;

  PermissionState copyWith({
    bool? microphoneGranted,
    bool? callGranted,
    bool? smsGranted,
    bool? locationGranted,
    bool? notificationGranted,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return PermissionState(
      microphoneGranted: microphoneGranted ?? this.microphoneGranted,
      callGranted: callGranted ?? this.callGranted,
      smsGranted: smsGranted ?? this.smsGranted,
      locationGranted: locationGranted ?? this.locationGranted,
      notificationGranted: notificationGranted ?? this.notificationGranted,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
