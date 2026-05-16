import 'package:flutter_test/flutter_test.dart';
import 'package:proteqme/features/listener/domain/help_detection_state_machine.dart';

void main() {
  group('HelpDetectionStateMachine', () {
    late HelpDetectionStateMachine machine;

    setUp(() {
      machine = HelpDetectionStateMachine();
    });

    test('triggers on HELP x3 within 10 seconds', () {
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      final first = machine.process(
        transcript: 'help',
        confidence: 0.9,
        at: base,
      );
      final second = machine.process(
        transcript: 'Help me',
        confidence: 0.9,
        at: base.add(const Duration(seconds: 3)),
      );
      final third = machine.process(
        transcript: 'HELP',
        confidence: 0.9,
        at: base.add(const Duration(seconds: 6)),
      );

      expect(
        first.any((e) => e.type == HelpDetectionEventType.helpDetected),
        isTrue,
      );
      expect(
        second.any((e) => e.type == HelpDetectionEventType.helpDetected),
        isTrue,
      );
      expect(
        third.any((e) => e.type == HelpDetectionEventType.triggered),
        isTrue,
      );
      expect(
        third.any((e) => e.type == HelpDetectionEventType.cooldown),
        isTrue,
      );
    });

    test('debounces detections within 2 seconds', () {
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      machine.process(transcript: 'help', confidence: 0.9, at: base);
      machine.process(
        transcript: 'help',
        confidence: 0.9,
        at: base.add(const Duration(milliseconds: 500)),
      );
      machine.process(
        transcript: 'help',
        confidence: 0.9,
        at: base.add(const Duration(seconds: 3)),
      );

      expect(machine.count, 2);
    });

    test('resets window after 10 seconds without reaching 3', () {
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      machine.process(transcript: 'help', confidence: 0.9, at: base);
      final events = machine.process(
        transcript: 'hello there',
        confidence: 0.9,
        at: base.add(const Duration(seconds: 11)),
      );

      expect(
        events.any((e) => e.type == HelpDetectionEventType.windowReset),
        isTrue,
      );
      expect(machine.count, 0);
    });

    test('applies 60-second cooldown after trigger', () {
      final base = DateTime(2026, 1, 1, 12, 0, 0);

      machine.process(transcript: 'help', confidence: 0.9, at: base);
      machine.process(
        transcript: 'help',
        confidence: 0.9,
        at: base.add(const Duration(seconds: 3)),
      );
      machine.process(
        transcript: 'help',
        confidence: 0.9,
        at: base.add(const Duration(seconds: 6)),
      );

      final blocked = machine.process(
        transcript: 'help',
        confidence: 0.9,
        at: base.add(const Duration(seconds: 10)),
      );

      expect(
        blocked.any((e) => e.type == HelpDetectionEventType.cooldown),
        isTrue,
      );
      expect(
        blocked.any((e) => e.type == HelpDetectionEventType.triggered),
        isFalse,
      );
    });

    test(
      'ignores low-confidence results but counts when confidence missing',
      () {
        final base = DateTime(2026, 1, 1, 12, 0, 0);

        final lowConfidence = machine.process(
          transcript: 'help',
          confidence: 0.2,
          at: base,
        );

        final noConfidence = machine.process(
          transcript: 'help',
          confidence: null,
          at: base.add(const Duration(seconds: 3)),
        );

        expect(
          lowConfidence.where(
            (e) => e.type == HelpDetectionEventType.helpDetected,
          ),
          isEmpty,
        );
        expect(
          noConfidence.any(
            (e) => e.type == HelpDetectionEventType.helpDetected,
          ),
          isTrue,
        );
      },
    );
  });
}
