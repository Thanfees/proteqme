import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/platform/platform_utils.dart';
import '../domain/entities/detection_event.dart';
import '../domain/usecases/get_service_status_usecase.dart';
import '../domain/usecases/start_listening_usecase.dart';
import '../domain/usecases/stop_listening_usecase.dart';
import '../domain/usecases/update_primary_number_usecase.dart';
import '../data/method_channel_listener_service_repository.dart';

class ListenerControllerState {
  const ListenerControllerState({
    required this.running,
    required this.iosForegroundMode,
    required this.cooldownRemaining,
    required this.logs,
    required this.loading,
    this.error,
  });

  const ListenerControllerState.initial()
    : running = false,
      iosForegroundMode = false,
      cooldownRemaining = 0,
      logs = const <DetectionEvent>[],
      loading = false,
      error = null;

  final bool running;
  final bool iosForegroundMode;
  final int cooldownRemaining;
  final List<DetectionEvent> logs;
  final bool loading;
  final String? error;

  bool get activeListening =>
      PlatformUtils.isAndroid ? running : iosForegroundMode;

  ListenerControllerState copyWith({
    bool? running,
    bool? iosForegroundMode,
    int? cooldownRemaining,
    List<DetectionEvent>? logs,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ListenerControllerState(
      running: running ?? this.running,
      iosForegroundMode: iosForegroundMode ?? this.iosForegroundMode,
      cooldownRemaining: cooldownRemaining ?? this.cooldownRemaining,
      logs: logs ?? this.logs,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ListenerController extends Notifier<ListenerControllerState> {
  late final StartListeningUseCase _startListening;
  late final StopListeningUseCase _stopListening;
  late final UpdatePrimaryNumberUseCase _updatePrimary;
  late final GetServiceStatusUseCase _getServiceStatus;

  Timer? _statusTimer;
  StreamSubscription<DetectionEvent>? _eventSubscription;

  @override
  ListenerControllerState build() {
    _startListening = ref.read(startListeningUseCaseProvider);
    _stopListening = ref.read(stopListeningUseCaseProvider);
    _updatePrimary = ref.read(updatePrimaryNumberUseCaseProvider);
    _getServiceStatus = ref.read(getServiceStatusUseCaseProvider);

    if (PlatformUtils.isAndroid) {
      final repository = ref.read(
        methodChannelListenerServiceRepositoryProvider,
      );
      _eventSubscription = repository.events.listen(
        _handleDetectionEvent,
        onError: (Object error, StackTrace stackTrace) {
          state = state.copyWith(error: 'Event channel error: $error');
        },
      );

      Future<void>.microtask(refreshStatus);
      _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        refreshStatus();
      });
    }

    ref.onDispose(() {
      _statusTimer?.cancel();
      _eventSubscription?.cancel();
    });

    return const ListenerControllerState.initial();
  }

  Future<void> refreshStatus() async {
    if (!PlatformUtils.isAndroid) {
      return;
    }

    try {
      final serviceStatus = await _getServiceStatus();
      state = state.copyWith(
        running: serviceStatus.running,
        cooldownRemaining: serviceStatus.cooldownRemaining,
      );
    } catch (error) {
      state = state.copyWith(error: 'Status sync failed: $error');
    }
  }

  Future<void> startAndroid({
    required String primaryNumber,
    required List<String> allNumbers,
  }) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      await _startListening(
        primaryNumber: primaryNumber,
        allNumbers: allNumbers,
      );
      await refreshStatus();
    } catch (error) {
      state = state.copyWith(error: 'Unable to start listener: $error');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> stopAndroid() async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      await _stopListening();
      await refreshStatus();
    } catch (error) {
      state = state.copyWith(error: 'Unable to stop listener: $error');
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> updatePrimaryNumber({
    required String primaryNumber,
    required List<String> allNumbers,
  }) async {
    if (!PlatformUtils.isAndroid || !state.running) {
      return;
    }

    try {
      await _updatePrimary(
        primaryNumber: primaryNumber,
        allNumbers: allNumbers,
      );
    } catch (error) {
      state = state.copyWith(error: 'Primary number update failed: $error');
    }
  }

  void setIosForegroundMode(bool enabled) {
    state = state.copyWith(iosForegroundMode: enabled, clearError: true);
  }

  void _handleDetectionEvent(DetectionEvent event) {
    final updatedLogs = <DetectionEvent>[
      event,
      ...state.logs,
    ].take(AppConstants.detectionLogLimit).toList(growable: false);

    var cooldown = state.cooldownRemaining;
    if (event.type == DetectionEventType.cooldown) {
      cooldown = event.cooldownRemaining ?? cooldown;
    }

    state = state.copyWith(logs: updatedLogs, cooldownRemaining: cooldown);
  }
}

final listenerControllerProvider =
    NotifierProvider<ListenerController, ListenerControllerState>(
      ListenerController.new,
    );
