import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import 'permission_controller.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(permissionControllerProvider);
    final controller = ref.read(permissionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SOS Listener needs microphone, phone, SMS, and location permissions to trigger full emergency workflow.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _PermissionTile(
                        title: 'Microphone',
                        subtitle: 'Required to detect HELP phrase.',
                        granted: permissionState.microphoneGranted,
                        onRequest: controller.requestMicrophone,
                      ),
                      const SizedBox(height: 8),
                      _PermissionTile(
                        title: 'Phone',
                        subtitle:
                            'Required for automatic call using ACTION_CALL.',
                        granted: permissionState.callGranted,
                        onRequest: controller.requestCall,
                      ),
                      const SizedBox(height: 8),
                      _PermissionTile(
                        title: 'SMS',
                        subtitle:
                            'Required to send emergency SMS to all contacts.',
                        granted: permissionState.smsGranted,
                        onRequest: controller.requestSms,
                      ),
                      const SizedBox(height: 8),
                      _PermissionTile(
                        title: 'Location',
                        subtitle:
                            'Required to include your current location in SOS SMS.',
                        granted: permissionState.locationGranted,
                        onRequest: controller.requestLocation,
                      ),
                      const SizedBox(height: 8),
                      _PermissionTile(
                        title: 'Notifications',
                        subtitle:
                            'Recommended for foreground and trigger notifications.',
                        granted: permissionState.notificationGranted,
                        onRequest: controller.requestNotifications,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (permissionState.error != null)
                Text(
                  permissionState.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: permissionState.microphoneGranted
                      ? () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                            return;
                          }
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(AppRouter.home);
                        }
                      : null,
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: controller.openSettings,
                  child: const Text('Open App Settings'),
                ),
              ),
              if (permissionState.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onRequest,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.error_outline,
          color: granted ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle),
            ],
          ),
        ),
        TextButton(
          onPressed: granted ? null : onRequest,
          child: Text(granted ? 'Granted' : 'Allow'),
        ),
      ],
    );
  }
}
