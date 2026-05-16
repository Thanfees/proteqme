import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/contacts/contacts_setup_screen.dart';
import 'features/emergency/emergency_overlay.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

class ProteqMeApp extends StatelessWidget {
  const ProteqMeApp({
    super.key,
    required this.sosActive,
    required this.initialRoute,
  });

  final bool sosActive;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProteqMe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB71C1C)),
        useMaterial3: true,
      ),
      initialRoute: sosActive ? '/emergency' : initialRoute,
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/contacts': (_) => const ContactsSetupScreen(),
        '/home': (_) => const HomeScreen(),
        '/emergency': (_) => const EmergencyOverlay(),
      },
    );
  }
}

/// Resolves first screen before `runApp` to avoid home flash during SOS.
Future<AppBootstrap> resolveBootstrap() async {
  final prefs = await SharedPreferences.getInstance();
  final sosActive = prefs.getBool('sos_active_cache') ?? false;
  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
  final contactsDone = prefs.getBool('contacts_setup_complete') ?? false;

  String route = '/onboarding';
  if (onboardingDone && !contactsDone) {
    route = '/contacts';
  } else if (onboardingDone && contactsDone) {
    route = '/home';
  }

  return AppBootstrap(sosActive: sosActive, initialRoute: route);
}

class AppBootstrap {
  const AppBootstrap({required this.sosActive, required this.initialRoute});
  final bool sosActive;
  final String initialRoute;
}
