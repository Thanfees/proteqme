import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/method_channel_listener_service_repository.dart';

class UpdatePrimaryNumberUseCase {
  const UpdatePrimaryNumberUseCase(this._repository);

  final MethodChannelListenerServiceRepository _repository;

  Future<void> call({
    required String primaryNumber,
    required List<String> allNumbers,
  }) {
    return _repository.updatePrimaryNumber(
      primaryNumber: primaryNumber,
      allNumbers: allNumbers,
    );
  }
}

final updatePrimaryNumberUseCaseProvider = Provider<UpdatePrimaryNumberUseCase>(
  (ref) => UpdatePrimaryNumberUseCase(
    ref.watch(methodChannelListenerServiceRepositoryProvider),
  ),
);
