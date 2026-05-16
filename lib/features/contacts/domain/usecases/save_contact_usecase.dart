import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive_contact_repository.dart';
import '../entities/emergency_contact.dart';

class SaveContactUseCase {
  const SaveContactUseCase(this._repository);

  final HiveContactRepository _repository;

  Future<void> call(EmergencyContact contact) {
    return _repository.upsertContact(contact);
  }
}

final saveContactUseCaseProvider = Provider<SaveContactUseCase>(
  (ref) => SaveContactUseCase(ref.watch(hiveContactRepositoryProvider)),
);
