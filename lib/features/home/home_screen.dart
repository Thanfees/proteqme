import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../background/sos_trigger_controller.dart';
import '../../core/config/app_config.dart';
import '../../data/repositories/sos_repository.dart';
import '../../ml/audio_monitor_service.dart';
import '../contacts/contacts_setup_screen.dart';
import '../emergency/emergency_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sosRepo = SosRepository();
  int _smsInterval = AppConfig.defaultSmsIntervalSec;
  @override
  void initState() {
    super.initState();
    _loadSettings();
    AudioMonitorService.instance.start();
  }

  Future<void> _loadSettings() async {
    final state = await _sosRepo.getState();
    setState(() => _smsInterval = state.smsIntervalSec);
  }

  Future<void> _saveInterval(double value) async {
    final sec = value.round();
    await _sosRepo.updateSmsInterval(sec);
    setState(() => _smsInterval = sec);
  }

  Future<void> _simulateSos() async {
    await SosTriggerController.instance.trigger('debug');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const EmergencyOverlay(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _smsInterval / 60;
    return GestureDetector(
      onLongPress: _simulateSos,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ProteqMe'),
          actions: [
            IconButton(
              icon: const Icon(Icons.contacts),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ContactsSetupScreen(fromSettings: true),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.shield,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Monitoring active',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppConfig.kEnablePorcupine
                            ? 'Listening for wake words'
                            : 'ML detectors off — use debug trigger',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('SMS interval: ${minutes.toStringAsFixed(1)} min'),
              Slider(
                min: AppConfig.minSmsIntervalSec.toDouble(),
                max: AppConfig.maxSmsIntervalSec.toDouble(),
                divisions: 4,
                value: _smsInterval.toDouble(),
                label: '${(_smsInterval / 60).toStringAsFixed(1)} min',
                onChanged: _saveInterval,
              ),
              const Spacer(),
              const Text(
                'Long-press anywhere on this screen to simulate SOS (demo).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _simulateSos,
                icon: const Icon(Icons.warning_amber),
                label: const Text('Simulate SOS trigger'),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_complete', false);
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamed('/onboarding');
                },
                child: const Text('Battery optimization checklist'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
