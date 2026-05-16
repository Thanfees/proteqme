import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/permissions/permission_flow.dart';
import '../contacts/contacts_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _permissionsDone = false;

  Future<void> _requestPermissions() async {
    final ok = await PermissionFlow.requestEmergencyPermissions();
    setState(() => _permissionsDone = ok);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const ContactsSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ProteqMe Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: (_step + 1) / 3),
              const SizedBox(height: 24),
              if (_step == 0) ...[
                const Text(
                  'Emergency permissions',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ProteqMe needs SMS, phone, location, microphone, and '
                  'notifications to protect you offline.',
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _requestPermissions,
                  child: const Text('Grant permissions'),
                ),
                if (_permissionsDone)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Permissions granted — continue'),
                  ),
              ] else if (_step == 1) ...[
                const Text(
                  'Battery & autostart',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'On Xiaomi, Samsung, and Vivo devices: disable battery '
                  'optimization for ProteqMe and enable autostart so SOS '
                  'survives reboots (critical in Sri Lanka).',
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: PermissionFlow.openBatteryOptimizationSettings,
                  child: const Text('Open battery settings'),
                ),
                const Spacer(),
              ] else ...[
                const Text(
                  'You are protected offline',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Convex sync is optional and only used after an incident '
                  'ends. Emergency features never depend on the internet.',
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _finish,
                  child: const Text('Add emergency contacts'),
                ),
              ],
              const SizedBox(height: 12),
              if (_step < 2)
                TextButton(
                  onPressed: () {
                    if (_step == 0 && !_permissionsDone) return;
                    setState(() => _step++);
                  },
                  child: const Text('Next'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
