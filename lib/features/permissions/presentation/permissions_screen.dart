import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/widgets/brand_scaffold.dart';
import 'permission_controller.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(permissionControllerProvider);
    final controller = ref.read(permissionControllerProvider.notifier);

    return BrandScaffold(
      title: 'Permissions',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandCard(
            child: Row(
              children: const [
                Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFFF6AA7),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SOS Listener needs microphone, phone, SMS, and location '
                    'permissions to trigger the full emergency workflow.',
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
            label: 'REQUIRED PERMISSIONS',
            icon: Icons.lock_outline,
          ),
          BrandCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: [
                _PermissionRow(
                  icon: Icons.mic_outlined,
                  title: 'Microphone',
                  subtitle: 'Required to detect HELP phrase.',
                  granted: permissionState.microphoneGranted,
                  onRequest: controller.requestMicrophone,
                ),
                const _RowDivider(),
                _PermissionRow(
                  icon: Icons.call_outlined,
                  title: 'Phone',
                  subtitle:
                      'Required for automatic call using ACTION_CALL.',
                  granted: permissionState.callGranted,
                  onRequest: controller.requestCall,
                ),
                const _RowDivider(),
                _PermissionRow(
                  icon: Icons.sms_outlined,
                  title: 'SMS',
                  subtitle:
                      'Required to send emergency SMS to all contacts.',
                  granted: permissionState.smsGranted,
                  onRequest: controller.requestSms,
                ),
                const _RowDivider(),
                _PermissionRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  subtitle:
                      'Required to include your current location in SOS SMS.',
                  granted: permissionState.locationGranted,
                  onRequest: controller.requestLocation,
                ),
                const _RowDivider(),
                _PermissionRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle:
                      'Recommended for foreground and trigger notifications.',
                  granted: permissionState.notificationGranted,
                  onRequest: controller.requestNotifications,
                ),
              ],
            ),
          ),
          if (permissionState.error != null) ...[
            const SizedBox(height: 12),
            BrandCard(
              borderColor: const Color(0x66FF3B5C),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFF3B5C),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      permissionState.error!,
                      style: const TextStyle(color: Color(0xFFFFE7F2)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: permissionState.microphoneGranted
                ? () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                      return;
                    }
                    Navigator.of(context)
                        .pushReplacementNamed(AppRouter.home);
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: controller.openSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open App Settings'),
          ),
          if (permissionState.loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0x22FF63A4),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final accent =
        granted ? const Color(0xFF3BE77A) : const Color(0xFFFFB347);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFFFE7F2),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      granted ? Icons.check_circle : Icons.error_outline,
                      color: accent,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB59BC9),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x333BE77A),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x663BE77A)),
                  ),
                  child: const Text(
                    'Granted',
                    style: TextStyle(
                      color: Color(0xFF3BE77A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onRequest,
                  child: const Text(
                    'Allow',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
        ],
      ),
    );
  }
}
