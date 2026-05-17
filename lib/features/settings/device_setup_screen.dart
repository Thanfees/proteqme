import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/widgets/brand_scaffold.dart';

/// Poco / Xiaomi / HyperOS steps so listening + SOS are not killed.
class DeviceSetupScreen extends ConsumerWidget {
  const DeviceSetupScreen({super.key});

  Future<void> _openBattery(BuildContext context) async {
    await openAppSettings();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set Battery → No restrictions. Enable Autostart for ProteqMe.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BrandScaffold(
      title: 'Poco / Xiaomi setup',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandCard(
            borderColor: const Color(0x66FFB347),
            child: Row(
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFFB347),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'HyperOS (Poco F7) aggressively stops background apps. '
                    'Do ALL steps or SOS listening will turn off by itself.',
                    style: TextStyle(
                      color: Color(0xFFFFE7F2),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const BrandSectionHeader(
            label: 'SETUP STEPS',
            icon: Icons.checklist_rtl,
          ),
          _StepCard(
            number: '1',
            title: 'Battery — Unrestricted',
            body:
                'Settings → Apps → ProteqMe → Battery saver → No restrictions',
            actionLabel: 'Open app settings',
            onAction: () => _openBattery(context),
          ),
          const SizedBox(height: 12),
          _StepCard(
            number: '2',
            title: 'Autostart',
            body:
                'Security app → Autostart → enable ProteqMe (or Settings → Apps → Autostart)',
            actionLabel: 'Open settings',
            onAction: () => _openBattery(context),
          ),
          const SizedBox(height: 12),
          const _StepCard(
            number: '3',
            title: 'Lock in recent apps',
            body:
                'Open Recents → long-press ProteqMe card → Lock (prevents swipe-kill)',
          ),
          const SizedBox(height: 12),
          _StepCard(
            number: '4',
            title: 'Display pop-up while in background',
            body:
                'Apps → ProteqMe → Other permissions → Display pop-up windows → Allow',
            actionLabel: 'Open settings',
            onAction: () => _openBattery(context),
          ),
          const SizedBox(height: 12),
          _StepCard(
            number: '5',
            title: 'Notifications',
            body:
                'Allow notifications — required for the listening foreground alert',
            actionLabel: 'Request notification',
            onAction: () async {
              await Permission.notification.request();
            },
          ),
          const SizedBox(height: 12),
          _StepCard(
            number: '6',
            title: 'Send SMS without confirmation (CRITICAL)',
            body:
                'Apps → ProteqMe → Other permissions → "Send SMS" → Allow always.\n\n'
                'HyperOS shows a pop-up before every background SMS by default. '
                'During an emergency you may not see / dismiss it, so the SMS is silently dropped. '
                'This setting lets ProteqMe send without that pop-up.',
            actionLabel: 'Open app settings',
            onAction: () => _openBattery(context),
            criticalAccent: true,
          ),
          const SizedBox(height: 12),
          const _StepCard(
            number: '7',
            title: 'Verify SIM has SMS credit',
            body:
                'Free / data-only SIMs cannot send SMS. Test by sending a normal SMS '
                'from your dialer first. If that fails, contact your carrier.',
          ),
          const BrandSectionHeader(
            label: 'BATTERY OPTIMIZATION',
            icon: Icons.battery_charging_full,
          ),
          BrandCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Allow ProteqMe to run without Android battery '
                  'optimization throttling.',
                  style: TextStyle(
                    color: Color(0xFFD9C5E9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Permission.ignoreBatteryOptimizations.request();
                  },
                  icon: const Icon(Icons.battery_charging_full),
                  label: const Text(
                    'Request ignore battery optimization',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.criticalAccent = false,
  });

  final String number;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool criticalAccent;

  @override
  Widget build(BuildContext context) {
    final accent =
        criticalAccent ? const Color(0xFFFF3B5C) : const Color(0xFFFF6AA7);
    return BrandCard(
      borderColor: criticalAccent
          ? const Color(0xAAFF3B5C)
          : const Color(0x44FF63A4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFE7F2),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFFD9C5E9),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
