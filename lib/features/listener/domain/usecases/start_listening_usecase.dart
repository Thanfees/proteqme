import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/method_channel_listener_service_repository.dart';

class StartListeningUseCase {
  const StartListeningUseCase(this._repository);

  final MethodChannelListenerServiceRepository _repository;

  Future<void> call({
    required String primaryNumber,
    required List<String> allNumbers,
  }) {
    return _repository.startService(
      primaryNumber: primaryNumber,
      allNumbers: allNumbers,
    );
  }
}

final startListeningUseCaseProvider = Provider<StartListeningUseCase>(
  (ref) => StartListeningUseCase(
    ref.watch(methodChannelListenerServiceRepositoryProvider),
  ),
);
