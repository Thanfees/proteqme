import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/contact_sync_service.dart';
import '../../data/hive_contact_repository.dart';

class DeleteContactUseCase {
  const DeleteContactUseCase(this._repository, this._syncService);

  final HiveContactRepository _repository;
  final ContactSyncService _syncService;

  Future<void> call(String id) async {
    await _repository.deleteContact(id);
    _syncService.fullSync(); // Fire and forget
  }
}

final deleteContactUseCaseProvider = Provider<DeleteContactUseCase>(
  (ref) => DeleteContactUseCase(
    ref.watch(hiveContactRepositoryProvider),
    ref.watch(contactSyncServiceProvider),
  ),
);
