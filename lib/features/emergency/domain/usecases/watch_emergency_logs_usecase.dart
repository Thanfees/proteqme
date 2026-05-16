import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive_emergency_repository.dart';
import '../entities/emergency_event_log.dart';

class WatchEmergencyLogsUseCase {
  const WatchEmergencyLogsUseCase(this._repository);

  final HiveEmergencyRepository _repository;

  Stream<List<EmergencyEventLog>> call() {
    return _repository.watchLogs();
  }
}

final watchEmergencyLogsUseCaseProvider = Provider<WatchEmergencyLogsUseCase>(
  (ref) =>
      WatchEmergencyLogsUseCase(ref.watch(hiveEmergencyRepositoryProvider)),
);
