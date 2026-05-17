import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/otp_login_screen.dart';
import '../features/contacts/presentation/contacts_screen.dart';
import '../features/listener/presentation/launch_screen.dart';
import '../features/listener/presentation/home_screen.dart';
import '../features/listener/presentation/logs_screen.dart';
import '../features/permissions/presentation/permissions_screen.dart';
import '../features/rescue/presentation/rescuer_mode_screen.dart';
import '../features/settings/device_setup_screen.dart';
import '../features/settings/features_hub_screen.dart';
import '../features/settings/profile_screen.dart';

class AppRouter {
  const AppRouter._();

  static const String launch = '/launch';
  static const String home = '/';
  static const String permissions = '/permissions';
  static const String contacts = '/contacts';
  static const String logs = '/logs';
  static const String auth = '/auth';
  static const String otpLogin = '/otp-login';
  static const String features = '/features';
  static const String deviceSetup = '/device-setup';
  static const String rescuerMode = '/rescuer-mode';
  static const String profile = '/profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case launch:
        return MaterialPageRoute<void>(builder: (_) => const LaunchScreen());
      case permissions:
        return MaterialPageRoute<void>(
          builder: (_) => const PermissionsScreen(),
        );
      case contacts:
        return MaterialPageRoute<void>(builder: (_) => const ContactsScreen());
      case logs:
        return MaterialPageRoute<void>(builder: (_) => const LogsScreen());
      case auth:
        return MaterialPageRoute<void>(builder: (_) => const AuthScreen());
      case otpLogin:
        return MaterialPageRoute<void>(builder: (_) => const OtpLoginScreen());
      case features:
        return MaterialPageRoute<void>(builder: (_) => const FeaturesHubScreen());
      case deviceSetup:
        return MaterialPageRoute<void>(builder: (_) => const DeviceSetupScreen());
      case rescuerMode:
        return MaterialPageRoute<void>(
          builder: (_) => const RescuerModeScreen(),
        );
      case profile:
        return MaterialPageRoute<void>(builder: (_) => const ProfileScreen());
      case home:
      default:
        return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
    }
  }
}
