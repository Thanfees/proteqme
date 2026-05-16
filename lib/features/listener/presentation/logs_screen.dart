import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'listener_controller.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(listenerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detection Logs')),
      body: SafeArea(
        child: state.logs.isEmpty
            ? const Center(child: Text('No events yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.logs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final event = state.logs[index];
                  return Card(
                    child: ListTile(
                      title: Text(event.summary()),
                      subtitle: Text(
                        event.timestamp.toLocal().toIso8601String(),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
