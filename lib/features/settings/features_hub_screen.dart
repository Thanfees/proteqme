import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/widgets/brand_scaffold.dart';

/// All ProteqMe features in one place.
class FeaturesHubScreen extends StatelessWidget {
  const FeaturesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BrandScaffold(
      title: 'ProteqMe features',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandSectionHeader(label: 'SAFETY ESSENTIALS'),
          BrandCard(
            child: Column(
              children: [
                BrandTile(
                  icon: Icons.mic,
                  title: 'SOS listening',
                  subtitle:
                      'Background HELP detection — use switch on Home',
                  onTap: () => Navigator.pop(context),
                ),
                const _TileDivider(),
                BrandTile(
                  icon: Icons.person,
                  title: 'Your profile (name)',
                  subtitle:
                      'Name shown in every SOS SMS your contacts receive',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.profile),
                ),
                const _TileDivider(),
                BrandTile(
                  icon: Icons.groups,
                  title: 'Emergency contacts',
                  subtitle: 'Add manually or import from phone',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.contacts),
                ),
                const _TileDivider(),
                BrandTile(
                  icon: Icons.cloud,
                  title: 'Cloud vault (Convex)',
                  subtitle: 'OTP login + sync contacts across devices',
                  onTap: () => Navigator.pushNamed(context, AppRouter.auth),
                ),
              ],
            ),
          ),
          const BrandSectionHeader(
            label: 'RESCUE MESH (BLUETOOTH / WI-FI DIRECT)',
            icon: Icons.bluetooth_searching,
          ),
          BrandCard(
            child: Column(
              children: [
                BrandTile(
                  icon: Icons.person_pin_circle,
                  title: 'I am in danger — victim',
                  subtitle:
                      'SOS auto-broadcasts your GPS over Bluetooth when you '
                      'trigger an alert. No extra action needed.',
                  accent: const Color(0xFFFF3B5C),
                  onTap: () => _showVictimInfo(context),
                ),
                const _TileDivider(),
                BrandTile(
                  icon: Icons.shield,
                  title: 'I am rescuing someone',
                  subtitle:
                      'Turn on rescuer scanning to find nearby SOS signals '
                      'and navigate to the victim.',
                  accent: const Color(0xFF4FC3F7),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.rescuerMode),
                ),
                const _TileDivider(),
                BrandTile(
                  icon: Icons.map,
                  title: 'Live family map (online)',
                  subtitle:
                      'Requires Convex login + internet during active SOS',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sign in via Cloud vault first, then trigger SOS while online.',
                        ),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const BrandSectionHeader(
            label: 'DEVICE & SECURITY',
            icon: Icons.security,
          ),
          BrandCard(
            child: Column(
              children: [
                BrandTile(
                  icon: Icons.phone_android,
                  title: 'Poco / Xiaomi device setup',
                  subtitle:
                      'Required on HyperOS so listening does not stop',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.deviceSetup),
                ),
                const _TileDivider(),
                BrandTile(
                  icon: Icons.security,
                  title: 'Permissions',
                  subtitle:
                      'Mic, location, phone, SMS, notifications, overlay',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRouter.permissions),
                ),
                const _TileDivider(),
                BrandTile(
                  icon: Icons.receipt_long,
                  title: 'Detection & emergency logs',
                  subtitle: 'HELP detections and SOS actions history',
                  onTap: () => Navigator.pushNamed(context, AppRouter.logs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVictimInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SOS + rescue mesh'),
        content: const Text(
          'When you press the SOS button, ProteqMe automatically:\n\n'
          '1. Sends your location by SMS to all emergency contacts\n'
          '2. Calls them in sequence\n'
          '3. Broadcasts your GPS over Bluetooth so nearby rescuers '
          'with ProteqMe can find you even without internet\n\n'
          'Press "I AM SAFE" (biometric required) to stop everything '
          'including the rescue broadcast.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0x22FF63A4),
    );
  }
}
