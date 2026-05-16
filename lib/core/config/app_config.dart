/// ProteqMe runtime configuration and ML feature flags.
class AppConfig {
  AppConfig._();

  static const String appName = 'ProteqMe';

  /// Porcupine English wake word — disabled until `.ppn` assets exist.
  static const bool kEnablePorcupine = false;

  /// YAMNet scream detector — disabled until `.tflite` assets exist.
  static const bool kEnableTfliteScream = false;

  /// Regional Sinhala/Tamil custom wake model — disabled until trained.
  static const bool kEnableRegionalWake = false;

  /// Default SMS interval (seconds) — 6 minutes.
  static const int defaultSmsIntervalSec = 360;

  static const int minSmsIntervalSec = 300;
  static const int maxSmsIntervalSec = 420;

  /// Call answered threshold (seconds) per spec.
  static const int callAnsweredThresholdSec = 40;

  static const int callRetryDelaySec = 5;

  static const int gpsTimeoutSec = 25;

  static const String emergencyNotificationChannelId = 'proteqme_emergency';
  static const String monitoringNotificationChannelId = 'proteqme_monitoring';

  static const String foregroundServiceName = 'ProteqMe Emergency';
}
