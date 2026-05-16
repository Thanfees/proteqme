import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive_contact_repository.dart';
import '../entities/emergency_contact.dart';

class GetPrimaryContactUseCase {
  const GetPrimaryContactUseCase(this._repository);

  final HiveContactRepository _repository;

  Future<EmergencyContact?> call() {
    return _repository.getPrimaryContact();
  }
}

final getPrimaryContactUseCaseProvider = Provider<GetPrimaryContactUseCase>(
  (ref) => GetPrimaryContactUseCase(ref.watch(hiveContactRepositoryProvider)),
);
