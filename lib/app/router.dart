import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/contacts/presentation/contacts_screen.dart';
import '../features/listener/presentation/launch_screen.dart';
import '../features/listener/presentation/home_screen.dart';
import '../features/listener/presentation/logs_screen.dart';
import '../features/permissions/presentation/permissions_screen.dart';

class AppRouter {
  const AppRouter._();

  static const String launch = '/launch';
  static const String home = '/';
  static const String permissions = '/permissions';
  static const String contacts = '/contacts';
  static const String logs = '/logs';
  static const String auth = '/auth';

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
      case home:
      default:
        return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
    }
  }
}
