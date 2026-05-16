import 'dart:async';

import 'package:phone_state/phone_state.dart';

import '../core/config/app_config.dart';
import '../core/constants/message_templates.dart';
import '../data/models/contact.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/sos_repository.dart';
import '../services/location_service.dart';
import '../services/telephony_service.dart';

/// Runs inside foreground service isolate — owns SMS loop and call escalation.
class EmergencyOrchestrator {
  EmergencyOrchestrator({
    ContactRepository? contactRepository,
    SosRepository? sosRepository,
    LocationService? locationService,
    TelephonyService? telephonyService,
  })  : _contacts = contactRepository ?? ContactRepository(),
        _sos = sosRepository ?? SosRepository(),
        _location = locationService ?? LocationService(),
        _telephony = telephonyService ?? TelephonyService();

  final ContactRepository _contacts;
  final SosRepository _sos;
  final LocationService _location;
  final TelephonyService _telephony;

  Timer? _smsTimer;
  StreamSubscription<PhoneState>? _phoneSub;
  bool _running = false;
  bool _disarmed = false;
  int _callIndex = 0;
  DateTime? _offhookAt;
  DateTime? _callStartedAt;

  Future<void> start({required String reason}) async {
    if (_running) return;
    _running = true;
    _disarmed = false;
    _callIndex = 0;

    final state = await _sos.getState();
    if (!state.isActive) {
      await _sos.activate(
        userName: state.userName.isNotEmpty ? state.userName : 'ProteqMe User',
        smsIntervalSec: state.smsIntervalSec,
        triggerReason: reason,
      );
    }

    await _runSmsTick();
    _scheduleSmsLoop();
    unawaited(_runCallEscalation());
  }

  void _scheduleSmsLoop() {
    _smsTimer?.cancel();
    _sos.getState().then((state) {
      if (!_running || _disarmed) return;
      _smsTimer = Timer(
        Duration(seconds: state.smsIntervalSec),
        () async {
          if (!_running || _disarmed) return;
          await _runSmsTick();
          _scheduleSmsLoop();
        },
      );
    });
  }

  Future<void> _runSmsTick() async {
    final contacts = await _contacts.getAll();
    if (contacts.isEmpty) return;

    final state = await _sos.getState();
    final location = await _location.getCurrentOrLastKnown();
    if (location != null) {
      await _sos.logGps(
        lat: location.lat,
        lng: location.lng,
        accuracy: location.accuracy,
        source: location.source,
      );
    }

    final lat = location?.lat ?? 0.0;
    final lng = location?.lng ?? 0.0;
    final userName =
        state.userName.isNotEmpty ? state.userName : 'ProteqMe User';

    for (final contact in contacts) {
      final message = MessageTemplates.emergency(
        language: contact.language,
        userName: userName,
        lat: lat,
        lng: lng,
      );
      await _telephony.sendSms(phone: contact.phone, message: message);
    }
  }

  Future<void> _runCallEscalation() async {
    while (_running && !_disarmed) {
      final state = await _sos.getState();
      if (state.callPaused) break;

      final contacts = await _contacts.getAll();
      if (contacts.isEmpty || _callIndex >= contacts.length) break;

      final contact = contacts[_callIndex];
      final duration = await _dialAndMeasure(contact);
      if (!_running || _disarmed) break;

      if (duration >= AppConfig.callAnsweredThresholdSec) {
        await _sos.setCallPaused(true);
        break;
      }

      await _sos.logCall(
        contactId: contact.id,
        startedAt: _callStartedAt ?? DateTime.now(),
        endedAt: DateTime.now(),
        durationSec: duration,
        outcome: 'not_answered',
      );

      _callIndex++;
      await Future<void>.delayed(
        Duration(seconds: AppConfig.callRetryDelaySec),
      );
    }
  }

  Future<int> _dialAndMeasure(Contact contact) async {
    _callStartedAt = DateTime.now();
    _offhookAt = null;
    final endCompleter = Completer<int>();

    await _phoneSub?.cancel();
    _phoneSub = PhoneState.stream.listen((event) {
      final status = event.status;
      if (status == PhoneStateStatus.CALL_STARTED ||
          status == PhoneStateStatus.CALL_INCOMING) {
        _offhookAt ??= DateTime.now();
      }
      if (status == PhoneStateStatus.CALL_ENDED) {
        final started = _callStartedAt ?? DateTime.now();
        final offhook = _offhookAt;
        final duration = offhook != null
            ? DateTime.now().difference(offhook).inSeconds
            : DateTime.now().difference(started).inSeconds;
        if (!endCompleter.isCompleted) {
          endCompleter.complete(duration);
        }
      }
    });

    await _telephony.callNumber(contact.phone);

    final duration = await endCompleter.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => 0,
    );

    await _phoneSub?.cancel();
    _phoneSub = null;

    await _sos.logCall(
      contactId: contact.id,
      startedAt: _callStartedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      durationSec: duration,
      outcome: duration >= AppConfig.callAnsweredThresholdSec
          ? 'answered'
          : 'not_answered',
    );

    return duration;
  }

  Future<void> disarm() async {
    if (_disarmed) return;
    _disarmed = true;
    _running = false;
    _smsTimer?.cancel();
    await _phoneSub?.cancel();

    final contacts = await _contacts.getAll();
    final state = await _sos.getState();
    final userName =
        state.userName.isNotEmpty ? state.userName : 'ProteqMe User';

    for (final contact in contacts) {
      final message = MessageTemplates.resolved(
        language: contact.language,
        userName: userName,
      );
      await _telephony.sendSms(phone: contact.phone, message: message);
    }

    final incident = await _sos.buildIncidentPayload();
    await _sos.queueSyncPayload({
      'type': 'incident_complete',
      ...incident,
    });
    await _sos.deactivate();
    await _sos.clearIncidentLogs();
  }

  void dispose() {
    _smsTimer?.cancel();
    _phoneSub?.cancel();
    _running = false;
  }
}
