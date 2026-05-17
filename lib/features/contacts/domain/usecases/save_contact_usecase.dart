import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/contact_sync_service.dart';
import '../../data/hive_contact_repository.dart';
import '../entities/emergency_contact.dart';

class SaveContactUseCase {
  const SaveContactUseCase(this._repository, this._syncService);

  final HiveContactRepository _repository;
  final ContactSyncService _syncService;

  Future<void> call(EmergencyContact contact) async {
    await _repository.upsertContact(contact);
    _syncService.fullSync(); // Fire and forget
  }
}

final saveContactUseCaseProvider = Provider<SaveContactUseCase>(
  (ref) => SaveContactUseCase(
    ref.watch(hiveContactRepositoryProvider),
    ref.watch(contactSyncServiceProvider),
  ),
);
