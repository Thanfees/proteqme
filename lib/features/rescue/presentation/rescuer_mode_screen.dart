import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/brand_scaffold.dart';
import '../rescue_mode_service.dart';

/// The rescuer's discovery screen.
///
/// A rescuer opens this, turns the toggle on, and the app searches for nearby
/// ProteqMe devices that are in active SOS mode.  The victim's phone
/// auto-advertises as soon as they trigger SOS — no action needed on their end.
class RescuerModeScreen extends ConsumerStatefulWidget {
  const RescuerModeScreen({super.key});

  @override
  ConsumerState<RescuerModeScreen> createState() => _RescuerModeScreenState();
}

class _RescuerModeScreenState extends ConsumerState<RescuerModeScreen> {
  bool _scanning = false;
  List<DiscoveredVictim> _victims = const [];
  StreamSubscription<List<DiscoveredVictim>>? _sub;
  String? _error;

  RescueModeService get _service => ref.read(rescueModeServiceProvider);

  Future<void> _toggle(bool enable) async {
    setState(() => _error = null);

    if (enable) {
      await _service.startDiscovery();
      _sub = _service.victims.listen((list) {
        if (mounted) setState(() => _victims = list);
      });
      setState(() {
        _scanning = true;
        _victims = _service.currentVictims;
      });
    } else {
      await _service.stopDiscovery();
      _sub?.cancel();
      _sub = null;
      setState(() {
        _scanning = false;
        _victims = const [];
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_scanning) _service.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandScaffold(
      title: 'Rescuer Mode',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BrandSectionHeader(
            label: 'HOW IT WORKS',
            icon: Icons.info_outline,
          ),
          const _InfoBanner(),
          const BrandSectionHeader(
            label: 'SCANNING',
            icon: Icons.bluetooth_searching,
          ),
          _ScanToggleCard(scanning: _scanning, onChanged: _toggle),
          if (_error != null) ...[
            const SizedBox(height: 12),
            BrandCard(
              borderColor: const Color(0x66FFB347),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFB347),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFFE7F2)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_scanning) ...[
            const BrandSectionHeader(
              label: 'NEARBY SOS DEVICES',
              icon: Icons.person_pin_circle,
            ),
            if (_victims.isEmpty)
              const _EmptyScanning()
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < _victims.length; i++) ...[
                    _VictimCard(victim: _victims[i]),
                    if (i != _victims.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
          ] else
            const _IdleMessage(),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: Color(0xFFFF6AA7),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'How rescuer mode works',
                style: TextStyle(
                  color: Color(0xFFFFE7F2),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '• Victim\'s phone auto-broadcasts via Bluetooth when SOS is triggered\n'
            '• You (rescuer) turn on scanning here to find nearby victims\n'
            '• Works without internet — uses Google Nearby Connections\n'
            '• Stay within ~100 m of the victim for best results',
            style: TextStyle(
              color: Color(0xFFD9C5E9),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanToggleCard extends StatelessWidget {
  const _ScanToggleCard({required this.scanning, required this.onChanged});

  final bool scanning;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      borderColor: scanning
          ? const Color(0xAA4FC3F7)
          : const Color(0x44FF63A4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (scanning
                      ? const Color(0xFF4FC3F7)
                      : const Color(0xFF8A7A9B))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (scanning
                        ? const Color(0xFF4FC3F7)
                        : const Color(0xFF8A7A9B))
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              scanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
              color: scanning
                  ? const Color(0xFF4FC3F7)
                  : const Color(0xFF8A7A9B),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scanning ? 'Scanning for victims…' : 'Scanning off',
                  style: const TextStyle(
                    color: Color(0xFFFFE7F2),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scanning
                      ? 'Looking for SOS signals nearby'
                      : 'Tap to start scanning',
                  style: const TextStyle(
                    color: Color(0xFFB59BC9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: scanning,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF4FC3F7),
            activeTrackColor: const Color(0xFF1A4A5A),
          ),
        ],
      ),
    );
  }
}

class _EmptyScanning extends StatefulWidget {
  const _EmptyScanning();

  @override
  State<_EmptyScanning> createState() => _EmptyScanningState();
}

class _EmptyScanningState extends State<_EmptyScanning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _pulse,
              child: const Icon(
                Icons.bluetooth_searching,
                color: Color(0xFF4FC3F7),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scanning…',
              style: TextStyle(
                color: Color(0xFFFFE7F2),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No SOS signals detected yet.\nMove closer to the victim.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB59BC9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleMessage extends StatelessWidget {
  const _IdleMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.search_off,
            color: Color(0xFF8A7A9B),
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'Turn on scanning to find\nnearby SOS signals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFE7F2),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Rescuer mode is idle. Toggle scanning above when you need '
            'to locate a nearby victim.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB59BC9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _VictimCard extends StatelessWidget {
  const _VictimCard({required this.victim});

  final DiscoveredVictim victim;

  Future<void> _openMap() async {
    final uri = Uri.parse(victim.mapsLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(victim.discoveredAt);
    final age = elapsed.inSeconds < 60
        ? '${elapsed.inSeconds}s ago'
        : '${elapsed.inMinutes}m ago';

    return BrandCard(
      borderColor: const Color(0xAAFF3B5C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_pin_circle,
                color: Color(0xFFFF3B5C),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  victim.userName,
                  style: const TextStyle(
                    color: Color(0xFFFFE7F2),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33FF3B5C),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x66FF3B5C)),
                ),
                child: Text(
                  'Found $age',
                  style: const TextStyle(
                    color: Color(0xFFFFB1B1),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFFB59BC9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${victim.lat.toStringAsFixed(5)}, '
                '${victim.lng.toStringAsFixed(5)}',
                style: const TextStyle(
                  color: Color(0xFFD9C5E9),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B5C),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _openMap,
              icon: const Icon(Icons.directions, size: 20),
              label: const Text(
                'Navigate to victim',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
