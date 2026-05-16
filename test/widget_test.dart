import 'package:flutter_test/flutter_test.dart';
import 'package:proteqme/core/constants/message_templates.dart';

void main() {
  test('emergency SMS includes maps link', () {
    final msg = MessageTemplates.emergency(
      language: 'en',
      userName: 'Ada',
      lat: 6.9,
      lng: 79.8,
    );
    expect(msg, contains('https://maps.google.com/?q=6.9,79.8'));
    expect(msg, contains('Ada'));
  });

  test('resolved SMS per language', () {
    expect(
      MessageTemplates.resolved(language: 'en', userName: 'Ada'),
      contains('RESOLVED'),
    );
  });
}
