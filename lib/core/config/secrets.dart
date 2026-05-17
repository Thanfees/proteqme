/// Runtime secrets — pass via `--dart-define` to override, otherwise
/// the defaults below connect to the dev deployment automatically.
class Secrets {
  Secrets._();

  static const String convexUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: 'https://ceaseless-elk-325.convex.cloud',
  );

  /// Deploy key is only needed for admin-level mutations.
  /// For normal client HTTP calls the public URL is sufficient.
  static const String convexDeployKey = String.fromEnvironment(
    'CONVEX_DEPLOY_KEY',
    defaultValue: '',
  );

  static bool get hasConvex => convexUrl.isNotEmpty;
}
