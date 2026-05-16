import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../data/local/app_database.dart';
import '../../../services/convex_service.dart';
import '../data/sos_loop_datasource.dart';
import '../../sync/convex_sync_worker.dart';

/// Full-screen lock while SOS loop is active; disarm requires biometrics/PIN.
class EmergencyOverlayScreen extends ConsumerStatefulWidget {
  const EmergencyOverlayScreen({super.key});

  @override
  ConsumerState<EmergencyOverlayScreen> createState() =>
      _EmergencyOverlayScreenState();
}

class _EmergencyOverlayScreenState extends ConsumerState<EmergencyOverlayScreen> {
  final _auth = LocalAuthentication();
  bool _disarming = false;
  String? _error;

  Future<void> _disarm() async {
    setState(() {
      _disarming = true;
      _error = null;
    });

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!canCheck && !supported) {
        setState(() => _error = 'No biometric or device lock configured.');
        return;
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Confirm your identity to stop the SOS loop',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!ok) {
        setState(() => _error = 'Authentication failed. SOS continues.');
        return;
      }

      await SosLoopDatasource().disarm();
      final db = await AppDatabase.instance();
      await db.setSosActive(active: false);
      final convex = ConvexService.tryCreate();
      if (convex != null) {
        await ConvexSyncWorker(convex, db).drainPending();
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _error = 'Disarm error: $e');
    } finally {
      if (mounted) {
        setState(() => _disarming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0008),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFF3B5C), size: 72),
                const SizedBox(height: 16),
                Text(
                  'SOS ACTIVE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ProteqMe is sending your location by SMS every few minutes '
                  'and calling your emergency contacts. This cannot be stopped '
                  'without verifying your identity.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const Spacer(),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _disarming ? null : _disarm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: _disarming
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'I AM SAFE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
