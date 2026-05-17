import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/brand_scaffold.dart';
import '../domain/entities/detection_event.dart';
import 'listener_controller.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(listenerControllerProvider);
    final logs = state.logs;

    return BrandScaffold(
      title: 'Detection Logs',
      body: logs.isEmpty
          ? const _EmptyLogs()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrandSectionHeader(
                  label: 'RECENT EVENTS · ${logs.length}',
                  icon: Icons.history_rounded,
                ),
                BrandCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      for (int i = 0; i < logs.length; i++) ...[
                        _LogRow(event: logs[i]),
                        if (i != logs.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0x22FF63A4),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.event});

  final DetectionEvent event;

  ({IconData icon, Color color}) _iconFor(DetectionEventType type) {
    return switch (type) {
      DetectionEventType.helpDetected => (
        icon: Icons.mic_external_on_outlined,
        color: const Color(0xFFFFB347),
      ),
      DetectionEventType.windowReset => (
        icon: Icons.refresh_rounded,
        color: const Color(0xFFB59BC9),
      ),
      DetectionEventType.triggered => (
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFFFF3B5C),
      ),
      DetectionEventType.cooldown => (
        icon: Icons.timer_outlined,
        color: const Color(0xFF4FC3F7),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final meta = _iconFor(event.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: meta.color.withValues(alpha: 0.4)),
            ),
            child: Icon(meta.icon, color: meta.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary(),
                  style: const TextStyle(
                    color: Color(0xFFFFE7F2),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.timestamp.toLocal().toIso8601String(),
                  style: const TextStyle(
                    color: Color(0xFFB59BC9),
                    fontSize: 11,
                    fontFamily: 'monospace',
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

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.event_note_outlined,
            size: 48,
            color: Color(0xFF8A7A9B),
          ),
          SizedBox(height: 16),
          Text(
            'No events yet',
            style: TextStyle(
              color: Color(0xFFFFE7F2),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Detection events will appear here once SOS listening picks up '
              'a HELP phrase or triggers an emergency action.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB59BC9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
