/// Runtime secrets — pass via `--dart-define` or copy from `.example`.
class Secrets {
  Secrets._();

  static const String convexUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: '',
  );

  static const String convexDeployKey = String.fromEnvironment(
    'CONVEX_DEPLOY_KEY',
    defaultValue: '',
  );

  static bool get hasConvex =>
      convexUrl.isNotEmpty && convexDeployKey.isNotEmpty;
}
