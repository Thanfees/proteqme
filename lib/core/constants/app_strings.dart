class AppStrings {
  const AppStrings._();

  static const String statusListeningActive = 'Listening active';
  static const String statusStopped = 'Stopped';
  static const String statusMissingMicPermission =
      'Missing microphone permission';
  static const String statusMissingPhonePermission = 'Missing phone permission';
  static const String statusNoPrimaryContact = 'No primary contact selected';

  static String statusCooldown(int seconds) => 'In cooldown ($seconds seconds)';
}
