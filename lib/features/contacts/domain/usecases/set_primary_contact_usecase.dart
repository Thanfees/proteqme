import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/contact_sync_service.dart';
import '../../data/hive_contact_repository.dart';

class SetPrimaryContactUseCase {
  const SetPrimaryContactUseCase(this._repository, this._syncService);

  final HiveContactRepository _repository;
  final ContactSyncService _syncService;

  Future<void> call(String id) async {
    await _repository.setPrimary(id);
    _syncService.fullSync(); // Fire and forget
  }
}

final setPrimaryContactUseCaseProvider = Provider<SetPrimaryContactUseCase>(
  (ref) => SetPrimaryContactUseCase(
    ref.watch(hiveContactRepositoryProvider),
    ref.watch(contactSyncServiceProvider),
  ),
);
