import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router.dart';
import '../../../core/constants/app_strings.dart';
import '../../contacts/domain/entities/emergency_contact.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../../emergency/domain/entities/emergency_trigger_type.dart';
import '../../emergency/presentation/emergency_controller.dart';
import '../../emergency/presentation/emergency_overlay_screen.dart';
import '../../permissions/data/location_service_status_provider.dart';
import '../../permissions/presentation/permission_controller.dart';
import 'listener_controller.dart';

/// All possible states the home-screen GPS pill can be in.
///
/// Derived from the combination of (a) the runtime location permission and
/// (b) the live OS Location/GPS toggle reported by
/// [locationServiceEnabledProvider].
enum _GpsPillStatus { loading, connected, serviceOff, permissionMissing }

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

    final locationServiceAsync = ref.watch(locationServiceEnabledProvider);
    final gpsPill = _resolveGpsPillState(
      permissionGranted: permissionState.locationGranted,
      serviceAsync: locationServiceAsync,
    );

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
                    _HomeHeader(
                      onSettingsTap: () => Navigator.of(
                        context,
                      ).pushNamed(AppRouter.features),
                    ),
                    const SizedBox(height: 10),
                    _GpsStatusPill(
                      status: gpsPill.status,
                      label: gpsPill.label,
                      onTap: _gpsPillTapHandler(gpsPill.status),
                    ),
                    const SizedBox(height: 14),
                    _ListeningCard(
                      active: active,
                      loading: listenerState.loading,
                      error: listenerState.error,
                      statusText: statusText,
                      onToggle: (enabled) => _onToggle(
                        enabled,
                        context,
                        ref,
                        primaryContact,
                        contacts,
                      ),
                    ),
                    if (!active &&
                        permissionState.microphoneGranted &&
                        primaryContact != null) ...[
                      const SizedBox(height: 10),
                      Material(
                        color: const Color(0x44FF6B35),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                          ),
                          title: const Text(
                            'Listening stopped?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: const Text(
                            'On Poco/Xiaomi open Features → Poco setup, then turn listening on again.',
                            style: TextStyle(fontSize: 11),
                          ),
                          onTap: () => Navigator.of(
                            context,
                          ).pushNamed(AppRouter.deviceSetup),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
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
                          color: Color(0xFFB59BC9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (emergencyState.error != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          emergencyState.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFA6A6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _HomeActionCard(
                            icon: Icons.contacts_rounded,
                            title: 'Contacts',
                            subtitle: '${contacts.length} saved',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRouter.contacts),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HomeActionCard(
                            icon: Icons.dashboard_rounded,
                            title: 'Features',
                            subtitle: 'All tools',
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed(AppRouter.features),
                          ),
                        ),
                      ],
                    ),
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

      await controller.startListening(
        primaryNumber: primaryContact.phone,
        allNumbers: allNumbers,
      );
    } else {
      await controller.stopListening();
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

    if (!permissions.callGranted || !permissions.smsGranted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone and SMS permissions are required for ProteqMe to call and text '
            'your emergency contacts. Open Permissions and allow both.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
      return;
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

  Future<void> _openPermissions(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).pushNamed(AppRouter.permissions);
    if (!context.mounted) {
      return;
    }
    await ref.read(permissionControllerProvider.notifier).refresh();
  }

  /// Returns a tap handler for the GPS pill, or `null` if the pill should
  /// be inert (e.g. already connected, or while we're still checking).
  VoidCallback? _gpsPillTapHandler(_GpsPillStatus status) {
    switch (status) {
      case _GpsPillStatus.serviceOff:
        return () => Geolocator.openLocationSettings();
      case _GpsPillStatus.permissionMissing:
        return () => Geolocator.openAppSettings();
      case _GpsPillStatus.connected:
      case _GpsPillStatus.loading:
        return null;
    }
  }
}

/// Folds the runtime location permission and the live OS GPS service stream
/// into the single piece of state the pill needs to render itself.
({_GpsPillStatus status, String label}) _resolveGpsPillState({
  required bool permissionGranted,
  required AsyncValue<bool> serviceAsync,
}) {
  if (!permissionGranted) {
    return (
      status: _GpsPillStatus.permissionMissing,
      label: 'Location permission needed',
    );
  }

  return serviceAsync.when(
    data: (enabled) => enabled
        ? (status: _GpsPillStatus.connected, label: 'GPS Connected')
        : (
            status: _GpsPillStatus.serviceOff,
            label: 'GPS off — turn on Location',
          ),
    loading: () => (status: _GpsPillStatus.loading, label: 'Checking GPS…'),
    // Treat a stream error the same as "service off" so we still nudge the
    // user toward the right settings page instead of pretending GPS works.
    error: (_, _) => (
      status: _GpsPillStatus.serviceOff,
      label: 'GPS off — turn on Location',
    ),
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _BrandCircleLogo(size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'ProteqMe',
            style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFE7F2),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: onSettingsTap,
          icon: const Icon(
            Icons.settings_rounded,
            color: Color(0xFFD9C5E9),
            size: 24,
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

class _GpsStatusPill extends StatelessWidget {
  const _GpsStatusPill({
    required this.status,
    required this.label,
    this.onTap,
  });

  final _GpsPillStatus status;
  final String label;
  final VoidCallback? onTap;

  Color get _accentColor {
    switch (status) {
      case _GpsPillStatus.connected:
        return const Color(0xFF3BE77A);
      case _GpsPillStatus.serviceOff:
        return const Color(0xFFFFB347);
      case _GpsPillStatus.permissionMissing:
        return const Color(0xFFFF5C7A);
      case _GpsPillStatus.loading:
        return const Color(0xFFB59BC9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0x66171128),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD9C5E9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: pill,
        ),
      ),
    );
  }
}

class _ListeningCard extends StatelessWidget {
  const _ListeningCard({
    required this.active,
    required this.loading,
    required this.error,
    required this.statusText,
    required this.onToggle,
  });

  final bool active;
  final bool loading;
  final String? error;
  final String statusText;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_moon_outlined,
                color: Color(0xFFFF6AA7),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'SOS Listening Mode',
                  style: TextStyle(
                    color: Color(0xFFFFE7F2),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusPill(
                label: active ? 'Active' : 'Idle',
                active: active,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Color(0xFFD9C5E9),
                    fontSize: 12,
                  ),
                ),
              ),
              Switch(value: active, onChanged: loading ? null : onToggle),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              borderRadius: BorderRadius.all(Radius.circular(99)),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x44FF63A4)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD6221232), Color(0xD6171128)],
        ),
      ),
      padding: const EdgeInsets.all(16),
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

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
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
          border: Border.all(color: const Color(0x44FF63A4)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xD6221232), Color(0xD6171128)],
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
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFFE7F2),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB59BC9),
              ),
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
