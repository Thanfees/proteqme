import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/method_channel_listener_service_repository.dart';
import '../entities/listener_service_status.dart';

class GetServiceStatusUseCase {
  const GetServiceStatusUseCase(this._repository);

  final MethodChannelListenerServiceRepository _repository;

  Future<ListenerServiceStatus> call() {
    return _repository.getServiceStatus();
  }
}

final getServiceStatusUseCaseProvider = Provider<GetServiceStatusUseCase>(
  (ref) => GetServiceStatusUseCase(
    ref.watch(methodChannelListenerServiceRepositoryProvider),
  ),
);
