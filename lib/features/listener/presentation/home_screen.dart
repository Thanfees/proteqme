import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/platform/platform_utils.dart';
import '../../contacts/domain/entities/emergency_contact.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../emergency/domain/entities/emergency_trigger_type.dart';
import '../../emergency/presentation/emergency_controller.dart';
import '../../emergency/presentation/emergency_overlay_screen.dart';
import '../../permissions/presentation/permission_controller.dart';
import 'listener_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(permissionControllerProvider);
    final contactsAsync = ref.watch(contactsProvider);
    final contacts = contactsAsync.valueOrNull ?? const <EmergencyContact>[];
    final primaryContact = _findPrimary(contacts);

    final listenerState = ref.watch(listenerControllerProvider);
    final listenerController = ref.read(listenerControllerProvider.notifier);

    final emergencyState = ref.watch(emergencyControllerProvider);
    final emergencyLogs =
        ref.watch(emergencyLogsProvider).valueOrNull ?? const [];

    ref.listen<AsyncValue<List<EmergencyContact>>>(contactsProvider, (
      previous,
      next,
    ) {
      final updatedContacts = next.valueOrNull;
      if (updatedContacts == null || updatedContacts.isEmpty) {
        return;
      }

      final updatedPrimary = _findPrimary(updatedContacts);
      if (updatedPrimary == null) {
        return;
      }

      final numbers = updatedContacts
          .map((contact) => contact.phone.trim())
          .where((phone) => phone.isNotEmpty)
          .toSet()
          .toList(growable: false);

      listenerController.updatePrimaryNumber(
        primaryNumber: updatedPrimary.phone,
        allNumbers: numbers,
      );
    });

    final active = listenerState.activeListening;
    final statusText = _statusText(
      permissionState.microphoneGranted,
      primaryContact,
      listenerState.cooldownRemaining,
      active,
    );

    final gpsStatusText = permissionState.locationGranted
        ? 'GPS Connected'
        : 'Location unavailable';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF14071F), Color(0xFF0E0618), Color(0xFF06030D)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -150,
              right: -120,
              child: _GlowBlob(size: 300, color: Color(0x44FF4A94)),
            ),
            const Positioned(
              bottom: -180,
              left: -120,
              child: _GlowBlob(size: 360, color: Color(0x332D68FF)),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopRow(
                      onManageContactsTap: () =>
                          Navigator.of(context).pushNamed(AppRouter.contacts),
                    ),
                    const SizedBox(height: 14),
                    _GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3BE77A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Location Status',
                                  style: TextStyle(
                                    color: Color(0xFFBAA8C9),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  gpsStatusText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusPill(
                            label: active ? 'Active' : 'Idle',
                            active: active,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.shield_moon_outlined,
                                color: Color(0xFFFF6CA9),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Primary Contact',
                                      style: TextStyle(
                                        color: Color(0xFFBAA8C9),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      primaryContact == null
                                          ? 'No primary contact selected'
                                          : '${primaryContact.name} (${primaryContact.phone})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Cloud vault login',
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.auth),
                                icon: const Icon(
                                  Icons.cloud_outlined,
                                  color: Color(0xFFD9C5E9),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Detection Logs',
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed(AppRouter.logs),
                                icon: const Icon(
                                  Icons.receipt_long_outlined,
                                  color: Color(0xFFD9C5E9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SOS Listening Mode',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      statusText,
                                      style: const TextStyle(
                                        color: Color(0xFFCCB7DC),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: active,
                                onChanged: listenerState.loading
                                    ? null
                                    : (enabled) => _onToggle(
                                        enabled,
                                        context,
                                        ref,
                                        primaryContact,
                                        contacts,
                                      ),
                              ),
                            ],
                          ),
                          if (listenerState.loading) ...[
                            const SizedBox(height: 8),
                            const LinearProgressIndicator(
                              borderRadius: BorderRadius.all(
                                Radius.circular(99),
                              ),
                            ),
                          ],
                          if (listenerState.error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              listenerState.error!,
                              style: const TextStyle(
                                color: Color(0xFFFF8A8A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: _SosButton(
                        busy: emergencyState.loading,
                        onPressed: () => _onEmergencyTrigger(
                          context: context,
                          ref: ref,
                          triggerType: EmergencyTriggerType.emergencyButton,
                          primaryContact: primaryContact,
                          contacts: contacts,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        'Tap or press & hold for emergency alert',
                        style: TextStyle(
                          color: Color(0xFFB5A2C7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: const Color(0x551E102C),
                        ),
                        onPressed: emergencyState.loading
                            ? null
                            : () => _onEmergencyTrigger(
                                context: context,
                                ref: ref,
                                triggerType: EmergencyTriggerType.manualTrigger,
                                primaryContact: primaryContact,
                                contacts: contacts,
                              ),
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text(
                          'MANUAL TRIGGER',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    if (!permissionState.smsGranted ||
                        !permissionState.locationGranted) ...[
                      const SizedBox(height: 12),
                      _GlassCard(
                        borderColor: const Color(0x66FFA45E),
                        child: Text(
                          _buildPermissionWarning(
                            smsGranted: permissionState.smsGranted,
                            locationGranted: permissionState.locationGranted,
                          ),
                          style: const TextStyle(color: Color(0xFFFFD8BF)),
                        ),
                      ),
                    ],
                    if (emergencyState.error != null) ...[
                      const SizedBox(height: 12),
                      _GlassCard(
                        borderColor: const Color(0x66FF7D7D),
                        child: Text(
                          emergencyState.error!,
                          style: const TextStyle(color: Color(0xFFFFA6A6)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.people_alt_outlined,
                            title: 'Contact Save',
                            subtitle: 'Add trusted guardians',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRouter.contacts),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.tune_rounded,
                            title: 'Settings',
                            subtitle: 'Permissions & safety',
                            onTap: () => _openPermissions(context, ref),
                          ),
                        ),
                      ],
                    ),
                    if (emergencyLogs.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recent Emergency Events',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            for (final log in emergencyLogs.take(3))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.fiber_manual_record,
                                      size: 10,
                                      color: Color(0xFFFF5FA0),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${log.type}  -  ${DateTime.fromMillisecondsSinceEpoch(log.timestampMs).toLocal()}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (PlatformUtils.isIos) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'iOS supports manual trigger flows but not continuous background auto-call detection.',
                        style: TextStyle(
                          color: Color(0xFFD9C6E7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onToggle(
    bool enabled,
    BuildContext context,
    WidgetRef ref,
    EmergencyContact? primaryContact,
    List<EmergencyContact> contacts,
  ) async {
    final permissionState = ref.read(permissionControllerProvider);
    final controller = ref.read(listenerControllerProvider.notifier);

    if (enabled) {
      if (!permissionState.microphoneGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
        await _openPermissions(context, ref);
        return;
      }

      if (primaryContact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a primary contact first.')),
        );
        return;
      }

      final allNumbers = contacts
          .map((contact) => contact.phone.trim())
          .where((phone) => phone.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (PlatformUtils.isAndroid) {
        await controller.startAndroid(
          primaryNumber: primaryContact.phone,
          allNumbers: allNumbers,
        );
      } else {
        controller.setIosForegroundMode(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('iOS mode is foreground-only and cannot auto-call.'),
          ),
        );
      }
    } else {
      if (PlatformUtils.isAndroid) {
        await controller.stopAndroid();
      } else {
        controller.setIosForegroundMode(false);
      }
    }
  }

  Future<void> _onEmergencyTrigger({
    required BuildContext context,
    required WidgetRef ref,
    required EmergencyTriggerType triggerType,
    required EmergencyContact? primaryContact,
    required List<EmergencyContact> contacts,
  }) async {
    var permissions = ref.read(permissionControllerProvider);
    final controller = ref.read(emergencyControllerProvider.notifier);
    final permissionController = ref.read(
      permissionControllerProvider.notifier,
    );

    if (!permissions.callGranted ||
        !permissions.smsGranted ||
        !permissions.locationGranted) {
      final goPermissions = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Allow permissions?'),
          content: const Text(
            'For full emergency workflow, allow Phone, SMS, and Location permissions. '
            'Without them, fallback behavior will be used.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continue Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open Permissions'),
            ),
          ],
        ),
      );

      if (!context.mounted) {
        return;
      }

      if (goPermissions == true) {
        if (!permissions.callGranted) {
          await permissionController.requestCall();
        }
        if (!permissions.smsGranted) {
          await permissionController.requestSms();
        }
        if (!permissions.locationGranted) {
          await permissionController.requestLocation();
        }
        await permissionController.refresh();
        permissions = ref.read(permissionControllerProvider);
      }
    }

    final result = await controller.trigger(
      triggerType: triggerType,
      primaryContact: primaryContact,
      contacts: contacts,
      callPermissionGranted: permissions.callGranted,
      smsPermissionGranted: permissions.smsGranted,
      locationPermissionGranted: permissions.locationGranted,
    );

    if (!context.mounted) {
      return;
    }

    if (result == null) {
      final error = ref.read(emergencyControllerProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    if (!context.mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const EmergencyOverlayScreen(),
      ),
    );
  }

  EmergencyContact? _findPrimary(List<EmergencyContact> contacts) {
    for (final contact in contacts) {
      if (contact.isPrimary) {
        return contact;
      }
    }
    return null;
  }

  String _statusText(
    bool microphoneGranted,
    EmergencyContact? primaryContact,
    int cooldownRemaining,
    bool active,
  ) {
    if (!microphoneGranted) {
      return AppStrings.statusMissingMicPermission;
    }

    if (primaryContact == null) {
      return AppStrings.statusNoPrimaryContact;
    }

    if (cooldownRemaining > 0) {
      return AppStrings.statusCooldown(cooldownRemaining);
    }

    if (active) {
      return AppStrings.statusListeningActive;
    }

    return AppStrings.statusStopped;
  }

  String _buildPermissionWarning({
    required bool smsGranted,
    required bool locationGranted,
  }) {
    if (!smsGranted && !locationGranted) {
      return 'SMS and location permissions are missing. SMS will fall back to composer and location may be unavailable.';
    }
    if (!smsGranted) {
      return 'SMS permission is missing. The app will open SMS composer as fallback.';
    }
    return 'Location permission is missing. Emergency SMS will be sent without location.';
  }

  Future<void> _openPermissions(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).pushNamed(AppRouter.permissions);
    if (!context.mounted) {
      return;
    }
    await ref.read(permissionControllerProvider.notifier).refresh();
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.onManageContactsTap});

  final VoidCallback onManageContactsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _BrandCircleLogo(size: 56),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ProteqMe',
                style: GoogleFonts.cinzel(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFE7F2),
                ),
              ),
              const Text(
                'Your Personal Safety Companion',
                style: TextStyle(color: Color(0xFFB59BC9), fontSize: 12),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: const Color(0xFF2A143A),
          ),
          onPressed: onManageContactsTap,
          icon: const Icon(Icons.groups_2_outlined, size: 18),
          label: const Text(
            'Manage Contact',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _BrandCircleLogo extends StatelessWidget {
  const _BrandCircleLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFFFF6AA7), Color(0xFFD71962)],
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x66FF3E8D),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: ColoredBox(
              color: const Color(0xFFFFF8FC),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Image.asset(
                  'assets/branding/proteqher_logo.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF8F53EF),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.borderColor = const Color(0x44FF63A4),
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD6221232), Color(0xD6171128)],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPressed,
      onLongPress: busy ? null : onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final size in const [260.0, 220.0, 190.0])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33FF5DA1)),
              ),
            ),
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFF8ABA),
                  Color(0xFFFF4A95),
                  Color(0xFFD71862),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88FF4E99),
                  blurRadius: 34,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SOS',
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'EMERGENCY',
                        style: TextStyle(
                          color: Color(0xFFFFDAEC),
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x44FF5A9D)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xD6211431), Color(0xD6171026)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x33FF5FA3),
              ),
              child: Icon(icon, color: const Color(0xFFFF88BC)),
            ),
            const SizedBox(height: 22),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB29CC6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF3BE77A) : const Color(0xFFFFCD5F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: const Color(0x331C1628),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: size * 0.3)],
        ),
      ),
    );
  }
}
