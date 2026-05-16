import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/method_channel_listener_service_repository.dart';

class StopListeningUseCase {
  const StopListeningUseCase(this._repository);

  final MethodChannelListenerServiceRepository _repository;

  Future<void> call() {
    return _repository.stopService();
  }
}

final stopListeningUseCaseProvider = Provider<StopListeningUseCase>(
  (ref) => StopListeningUseCase(
    ref.watch(methodChannelListenerServiceRepositoryProvider),
  ),
);
