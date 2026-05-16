import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/entities/detection_event.dart';
import '../domain/entities/listener_service_status.dart';
import '../domain/repositories/listener_service_repository.dart';

class MethodChannelListenerServiceRepository
    implements ListenerServiceRepository {
  MethodChannelListenerServiceRepository();

  static const MethodChannel _methodChannel = MethodChannel(
    AppConstants.serviceMethodChannel,
  );
  static const EventChannel _eventChannel = EventChannel(
    AppConstants.serviceEventChannel,
  );

  Stream<DetectionEvent>? _eventsCache;

  @override
  Stream<DetectionEvent> get events {
    if (!Platform.isAndroid) {
      return const Stream<DetectionEvent>.empty();
    }

    _eventsCache ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic rawEvent) {
          final map = Map<String, dynamic>.from(
            rawEvent as Map<dynamic, dynamic>,
          );
          return DetectionEvent.fromMap(map);
        })
        .where((event) => event.timestamp.millisecondsSinceEpoch > 0)
        .asBroadcastStream();

    return _eventsCache!;
  }

  @override
  Future<ListenerServiceStatus> getServiceStatus() async {
    if (!Platform.isAndroid) {
      return const ListenerServiceStatus(running: false, cooldownRemaining: 0);
    }

    try {
      final map = await _methodChannel.invokeMapMethod<String, dynamic>(
        'getServiceStatus',
      );

      return ListenerServiceStatus(
        running: map?['running'] as bool? ?? false,
        cooldownRemaining: map?['cooldownRemaining'] as int? ?? 0,
      );
    } on MissingPluginException {
      return const ListenerServiceStatus(running: false, cooldownRemaining: 0);
    }
  }

  @override
  Future<void> startService({
    required String primaryNumber,
    required List<String> allNumbers,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    await _methodChannel.invokeMethod<void>('startService', {
      'primaryNumber': primaryNumber,
      'allNumbers': allNumbers,
    });
  }

  @override
  Future<void> stopService() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _methodChannel.invokeMethod<void>('stopService');
  }

  @override
  Future<void> updatePrimaryNumber({
    required String primaryNumber,
    required List<String> allNumbers,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    await _methodChannel.invokeMethod<void>('updatePrimaryNumber', {
      'primaryNumber': primaryNumber,
      'allNumbers': allNumbers,
    });
  }
}

final methodChannelListenerServiceRepositoryProvider =
    Provider<MethodChannelListenerServiceRepository>(
      (ref) => MethodChannelListenerServiceRepository(),
    );
