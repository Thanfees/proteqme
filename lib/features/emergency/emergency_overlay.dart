import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../background/emergency_service.dart';
import '../../data/repositories/sos_repository.dart';
import '../../sync/convex_sync_worker.dart';

class EmergencyOverlay extends StatefulWidget {
  const EmergencyOverlay({super.key});

  @override
  State<EmergencyOverlay> createState() => _EmergencyOverlayState();
}

class _EmergencyOverlayState extends State<EmergencyOverlay> {
  final _sosRepo = SosRepository();
  final _auth = LocalAuthentication();
  Timer? _tick;
  String _gpsText = 'Locating…';
  int _secondsToSms = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final state = await _sosRepo.getState();
    final gps = await _sosRepo.getGpsLog();
    if (gps.isNotEmpty) {
      final last = gps.last;
      _gpsText =
          '${last['lat']}, ${last['lng']} (${last['source']})';
    }
    if (state.triggeredAt != null) {
      final elapsed =
          DateTime.now().difference(state.triggeredAt!).inSeconds;
      _secondsToSms = state.smsIntervalSec - (elapsed % state.smsIntervalSec);
    }
    if (mounted) setState(() {});
  }

  Future<void> _disarm() async {
    try {
      final can = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!can && !supported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device authentication unavailable')),
        );
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Confirm you are safe to stop SOS',
        biometricOnly: false,
      );

      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed — SOS continues')),
        );
        return;
      }

      await EmergencyService.instance.disarm();
      await ConvexSyncWorker().syncPending();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disarm error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFB71C1C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SOS ACTIVE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Last location: $_gpsText',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next SMS in ~$_secondsToSms s',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Spacer(),
                const Text(
                  'Alerts cannot be cancelled without verifying your identity.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB71C1C),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: _disarm,
                  child: const Text(
                    'I AM SAFE',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
