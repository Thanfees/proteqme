import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/brand_scaffold.dart';
import '../domain/overwatch_state.dart';
import 'overwatch_controller.dart';

/// Drop-in card for the home screen that renders all four Overwatch phases
/// inside a single [BrandCard] surface.
///
/// * idle           — destination + duration presets + arm button.
/// * active         — large MM:SS countdown, "I Arrived Safely" button.
/// * expiringSoon   — same as active, pulsing red border + orange countdown.
/// * completed      — 3 s green success state then auto-collapses to idle.
class OverwatchCard extends ConsumerWidget {
  const OverwatchCard({super.key});

  static const Color _accentPink = Color(0xFFFFE7F2);
  static const Color _safeGreen = Color(0xFF3BE77A);
  static const Color _warnOrange = Color(0xFFFFB347);
  static const Color _dangerRed = Color(0xFFFF3B5C);
  static const Color _subText = Color(0xFFB59BC9);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overwatchControllerProvider);
    final controller = ref.read(overwatchControllerProvider.notifier);

    switch (state.phase) {
      case OverwatchPhase.idle:
        return _IdleSection(
          error: controller.lastError,
          onStart: (duration, destination) =>
              controller.start(durationSeconds: duration, destination: destination),
        );
      case OverwatchPhase.active:
        return _ActiveSection(
          state: state,
          error: controller.lastError,
          isExpiring: false,
          onArrivedSafely: () => controller.cancelWithBiometric(context),
        );
      case OverwatchPhase.expiringSoon:
        return _ActiveSection(
          state: state,
          error: controller.lastError,
          isExpiring: true,
          onArrivedSafely: () => controller.cancelWithBiometric(context),
        );
      case OverwatchPhase.completed:
        return const _CompletedSection();
    }
  }
}

class _IdleSection extends StatefulWidget {
  const _IdleSection({required this.error, required this.onStart});

  final String? error;
  final Future<void> Function(int duration, String destination) onStart;

  @override
  State<_IdleSection> createState() => _IdleSectionState();
}

class _IdleSectionState extends State<_IdleSection> {
  static const List<_DurationPreset> _presets = <_DurationPreset>[
    _DurationPreset(label: '15 min', seconds: 15 * 60),
    _DurationPreset(label: '30 min', seconds: 30 * 60),
    _DurationPreset(label: '1 hr', seconds: 60 * 60),
    _DurationPreset(label: '2 hr', seconds: 2 * 60 * 60),
  ];

  final TextEditingController _destinationController = TextEditingController();
  int _selectedSeconds = 30 * 60;
  bool _starting = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      borderColor: const Color(0x44FF63A4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: OverwatchCard._accentPink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: OverwatchCard._accentPink.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.shield_moon_rounded,
                  size: 20,
                  color: OverwatchCard._accentPink,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safe Journey Overwatch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: OverwatchCard._accentPink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Dead-man\'s switch — if you don\'t check in, your contacts get pinged.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: OverwatchCard._subText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((preset) {
              final selected = preset.seconds == _selectedSeconds;
              return ChoiceChip(
                label: Text(preset.label),
                selected: selected,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : OverwatchCard._accentPink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                selectedColor: const Color(0xFFD1437B),
                backgroundColor: const Color(0x33FF63A4),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFFFF63A4)
                      : const Color(0x44FF63A4),
                ),
                onSelected: (_) {
                  setState(() => _selectedSeconds = preset.seconds);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destinationController,
            style: const TextStyle(color: OverwatchCard._accentPink),
            decoration: InputDecoration(
              hintText: 'Going to… (optional)',
              hintStyle: const TextStyle(color: OverwatchCard._subText),
              prefixIcon:
                  const Icon(Icons.place_outlined, color: OverwatchCard._subText),
              filled: true,
              fillColor: const Color(0x33170B26),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x44FF63A4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x44FF63A4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF63A4)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 10),
            _ErrorRow(message: widget.error!),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _starting
                  ? null
                  : () async {
                      setState(() => _starting = true);
                      try {
                        await widget.onStart(
                          _selectedSeconds,
                          _destinationController.text,
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _starting = false);
                        }
                      }
                    },
              icon: const Icon(Icons.shield_moon_rounded),
              label: Text(
                _starting ? 'Arming…' : 'Start Overwatch',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD1437B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSection extends StatefulWidget {
  const _ActiveSection({
    required this.state,
    required this.error,
    required this.isExpiring,
    required this.onArrivedSafely,
  });

  final OverwatchState state;
  final String? error;
  final bool isExpiring;
  final Future<bool> Function() onArrivedSafely;

  @override
  State<_ActiveSection> createState() => _ActiveSectionState();
}

class _ActiveSectionState extends State<_ActiveSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _formatCountdown(widget.state.remainingSeconds);
    final countdownColor = widget.isExpiring
        ? OverwatchCard._warnOrange
        : OverwatchCard._accentPink;
    final progress = widget.state.totalSeconds == 0
        ? 0.0
        : (1.0 -
                widget.state.remainingSeconds / widget.state.totalSeconds)
            .clamp(0.0, 1.0);

    if (!widget.isExpiring) {
      return BrandCard(
        borderColor: const Color(0x66FF63A4),
        child: _buildBody(countdown, countdownColor, progress),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = _pulseController.value;
        final borderColor = Color.lerp(
          OverwatchCard._dangerRed.withValues(alpha: 0.45),
          OverwatchCard._dangerRed,
          t,
        )!;
        return BrandCard(
          borderColor: borderColor,
          child: child!,
        );
      },
      child: _buildBody(countdown, countdownColor, progress),
    );
  }

  Widget _buildBody(String countdown, Color countdownColor, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              widget.isExpiring
                  ? Icons.warning_amber_rounded
                  : Icons.shield_moon_rounded,
              size: 18,
              color: widget.isExpiring
                  ? OverwatchCard._warnOrange
                  : OverwatchCard._accentPink,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.isExpiring ? 'OVERWATCH EXPIRING' : 'OVERWATCH ACTIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: widget.isExpiring
                      ? OverwatchCard._warnOrange
                      : OverwatchCard._subText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            countdown,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: countdownColor,
              letterSpacing: 2,
              shadows: widget.isExpiring
                  ? <Shadow>[
                      Shadow(
                        color: OverwatchCard._warnOrange.withValues(alpha: 0.6),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: const Color(0x33FF63A4),
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isExpiring
                  ? OverwatchCard._warnOrange
                  : const Color(0xFFFF63A4),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.state.destination.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: OverwatchCard._subText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.state.destination,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OverwatchCard._accentPink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (widget.isExpiring) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: OverwatchCard._dangerRed.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: OverwatchCard._dangerRed.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: OverwatchCard._warnOrange,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Overwatch expiring! Please verify your safety.',
                    style: TextStyle(
                      color: OverwatchCard._warnOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.error != null) ...[
          const SizedBox(height: 10),
          _ErrorRow(message: widget.error!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.onArrivedSafely();
                  } finally {
                    if (mounted) {
                      setState(() => _busy = false);
                    }
                  }
                },
          icon: const Icon(Icons.verified_user_rounded),
          label: Text(
            _busy ? 'Verifying…' : 'I Arrived Safely',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: OverwatchCard._safeGreen,
            foregroundColor: const Color(0xFF003315),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCountdown(int seconds) {
    final s = seconds.clamp(0, 1 << 30);
    final hours = s ~/ 3600;
    final mins = (s % 3600) ~/ 60;
    final secs = s % 60;
    if (hours > 0) {
      final mm = mins.toString().padLeft(2, '0');
      final ss = secs.toString().padLeft(2, '0');
      return '${hours.toString()}:$mm:$ss';
    }
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _CompletedSection extends StatelessWidget {
  const _CompletedSection();

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      borderColor: OverwatchCard._safeGreen.withValues(alpha: 0.55),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: OverwatchCard._safeGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: OverwatchCard._safeGreen.withValues(alpha: 0.6),
              ),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: OverwatchCard._safeGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journey complete — stay safe!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OverwatchCard._accentPink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your overwatch has been cancelled.',
                  style: TextStyle(
                    fontSize: 12,
                    color: OverwatchCard._subText,
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

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OverwatchCard._dangerRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OverwatchCard._dangerRed.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: OverwatchCard._dangerRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: OverwatchCard._dangerRed,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationPreset {
  const _DurationPreset({required this.label, required this.seconds});

  final String label;
  final int seconds;
}
