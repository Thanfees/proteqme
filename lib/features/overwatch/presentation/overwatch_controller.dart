import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../data/local/app_database.dart';
import '../../contacts/data/hive_contact_repository.dart';
import '../../contacts/domain/entities/emergency_contact.dart';
import '../data/overwatch_platform_datasource.dart';
import '../domain/overwatch_state.dart';

/// How long the success state lingers before auto-collapsing to idle.
const Duration _kCompletedHoldDuration = Duration(seconds: 3);

/// Riverpod-driven controller for the Safe Journey / Overwatch dead-man's
/// switch.
///
/// Authoritative truth lives on the Android side (AlarmManager + SharedPrefs);
/// this controller maintains a 1 s UI tick + listens to the EventChannel for
/// pushed lifecycle events so the UI never lies about what native is doing.
class OverwatchController extends StateNotifier<OverwatchState> {
  OverwatchController(this._ref) : super(const OverwatchState.idle()) {
    _subscribeToEvents();
    // Pull initial state in case a timer was started in a previous app session.
    unawaited(refresh());
  }

  final Ref _ref;
  final LocalAuthentication _auth = LocalAuthentication();

  Timer? _uiTicker;
  Timer? _completedTimer;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  String? _lastError;

  /// Most recent error surfaced from start/cancel/auth — consumed by the card
  /// widget when it rebuilds. Nulled out after the user acks.
  String? get lastError => _lastError;

  @override
  void dispose() {
    _uiTicker?.cancel();
    _completedTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  /// Pull native status and reconcile UI state.
  Future<void> refresh() async {
    try {
      final datasource = _ref.read(overwatchPlatformDatasourceProvider);
      final status = await datasource.getStatus();
      if (status == null) {
        _stopUiTicker();
        if (state.phase != OverwatchPhase.completed) {
          state = const OverwatchState.idle();
        }
        return;
      }

      final remainingMs = (status['remainingMs'] as num?)?.toInt() ?? 0;
      final destination = status['destination'] as String? ?? '';
      final startAtMs = (status['startAtMs'] as num?)?.toInt() ?? 0;
      final endAtMs = (status['endAtMs'] as num?)?.toInt() ?? 0;
      final totalSeconds = ((endAtMs - startAtMs) / 1000).round();
      final remainingSeconds = (remainingMs / 1000).ceil().clamp(0, 1 << 30);

      state = state.copyWith(
        phase: _phaseFor(remainingSeconds),
        totalSeconds: totalSeconds,
        remainingSeconds: remainingSeconds,
        destination: destination,
        startedAtMs: startAtMs,
      );
      _startUiTicker();
    } catch (error) {
      _lastError = 'Status refresh failed: $error';
    }
  }

  /// Arm the dead-man's switch. Fetches the user's display name + emergency
  /// contacts and forwards them to native so the receiver can escalate even if
  /// the Flutter process is killed by the OS before expiry.
  Future<void> start({
    required int durationSeconds,
    required String destination,
  }) async {
    _lastError = null;
    _completedTimer?.cancel();
    if (durationSeconds <= 0) {
      _lastError = 'Pick a duration first.';
      state = state.copyWith();
      return;
    }

    try {
      final contactsRepo = _ref.read(hiveContactRepositoryProvider);
      final contacts = await contactsRepo.getContacts();
      if (contacts.isEmpty) {
        _lastError = 'Add at least one emergency contact before arming.';
        state = state.copyWith();
        return;
      }

      final primary = contacts.firstWhere(
        (EmergencyContact c) => c.isPrimary,
        orElse: () => contacts.first,
      );
      final db = await AppDatabase.instance();
      final userName = await db.getUserDisplayName();

      final sorted = List<EmergencyContact>.from(contacts)
        ..sort((EmergencyContact a, EmergencyContact b) {
          if (a.isPrimary != b.isPrimary) {
            return a.isPrimary ? -1 : 1;
          }
          return a.name.compareTo(b.name);
        });
      final payload = <Map<String, dynamic>>[];
      for (var i = 0; i < sorted.length; i++) {
        final c = sorted[i];
        payload.add(<String, dynamic>{
          'phone': c.phone,
          'name': c.name,
          'priority': i + 1,
          'language': c.language,
        });
      }

      await _ref.read(overwatchPlatformDatasourceProvider).start(
            durationSeconds: durationSeconds,
            destination: destination.trim(),
            userName: userName,
            primaryNumber: primary.phone,
            contactsJson: jsonEncode(payload),
          );

      state = OverwatchState(
        phase: _phaseFor(durationSeconds),
        totalSeconds: durationSeconds,
        remainingSeconds: durationSeconds,
        destination: destination.trim(),
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      _startUiTicker();
    } catch (error) {
      _lastError = 'Unable to arm overwatch: $error';
      state = state.copyWith();
    }
  }

  /// Cancel-with-biometric. Mirrors [EmergencyOverlayScreen]'s disarm flow —
  /// `isDeviceSupported()` first, then PIN-or-biometric. On success the native
  /// alarms are torn down and the card flashes [OverwatchPhase.completed] for
  /// 3 s before returning to idle. On failure the timer keeps running.
  Future<bool> cancelWithBiometric(BuildContext ctx) async {
    _lastError = null;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        _lastError =
            'No screen lock set up. Set a PIN, pattern, or fingerprint first.';
        state = state.copyWith();
        return false;
      }

      bool ok;
      try {
        ok = await _auth.authenticate(
          localizedReason: 'Confirm you arrived safely',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
            sensitiveTransaction: true,
          ),
        );
      } on PlatformException catch (e) {
        _lastError = 'Auth error: ${e.message ?? e.code}.';
        state = state.copyWith();
        return false;
      }

      if (!ok) {
        _lastError = 'Identity not confirmed — Overwatch continues.';
        state = state.copyWith();
        return false;
      }

      await _ref.read(overwatchPlatformDatasourceProvider).cancel();
      _completeAndCollapse();
      return true;
    } catch (error) {
      _lastError = 'Cancel failed: $error';
      state = state.copyWith();
      return false;
    }
  }

  void _subscribeToEvents() {
    final datasource = _ref.read(overwatchPlatformDatasourceProvider);
    _eventSubscription = datasource.events.listen(
      _handleNativeEvent,
      onError: (Object error, StackTrace _) {
        _lastError = 'Overwatch event stream error: $error';
      },
    );
  }

  void _handleNativeEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    switch (type) {
      case OverwatchEventType.tick:
        final remainingMs = (event['remainingMs'] as num?)?.toInt() ?? 0;
        final remainingSeconds = (remainingMs / 1000).ceil().clamp(0, 1 << 30);
        state = state.copyWith(
          remainingSeconds: remainingSeconds,
          phase: _phaseFor(remainingSeconds),
        );
        break;
      case OverwatchEventType.expiringSoon:
        HapticFeedback.heavyImpact();
        final remainingMs = (event['remainingMs'] as num?)?.toInt() ?? 60_000;
        final remainingSeconds = (remainingMs / 1000).ceil().clamp(0, 1 << 30);
        state = state.copyWith(
          phase: OverwatchPhase.expiringSoon,
          remainingSeconds: remainingSeconds,
        );
        break;
      case OverwatchEventType.expired:
        _stopUiTicker();
        state = const OverwatchState.idle();
        break;
      case OverwatchEventType.cancelled:
        _completeAndCollapse();
        break;
    }
  }

  void _startUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isActive) {
        _stopUiTicker();
        return;
      }
      final remaining = (state.remainingSeconds - 1).clamp(0, 1 << 30);
      if (remaining <= 0) {
        // Timer hit zero — re-pull native status to learn whether the receiver
        // already fired (EXPIRED), or whether the alarm slipped.
        unawaited(refresh());
        return;
      }
      state = state.copyWith(
        remainingSeconds: remaining,
        phase: _phaseFor(remaining),
      );
      if (remaining == 60) {
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _stopUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = null;
  }

  void _completeAndCollapse() {
    _stopUiTicker();
    state = state.copyWith(
      phase: OverwatchPhase.completed,
      remainingSeconds: 0,
    );
    _completedTimer?.cancel();
    _completedTimer = Timer(_kCompletedHoldDuration, () {
      if (state.phase == OverwatchPhase.completed) {
        state = const OverwatchState.idle();
      }
    });
  }

  OverwatchPhase _phaseFor(int remainingSeconds) {
    if (remainingSeconds <= 0) return OverwatchPhase.idle;
    if (remainingSeconds <= 60) return OverwatchPhase.expiringSoon;
    return OverwatchPhase.active;
  }
}

final overwatchControllerProvider =
    StateNotifierProvider<OverwatchController, OverwatchState>(
  (ref) => OverwatchController(ref),
);
