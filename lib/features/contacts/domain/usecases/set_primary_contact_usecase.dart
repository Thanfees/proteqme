import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive_contact_repository.dart';

class SetPrimaryContactUseCase {
  const SetPrimaryContactUseCase(this._repository);

  final HiveContactRepository _repository;

  Future<void> call(String id) {
    return _repository.setPrimary(id);
  }
}

final setPrimaryContactUseCaseProvider = Provider<SetPrimaryContactUseCase>(
  (ref) => SetPrimaryContactUseCase(ref.watch(hiveContactRepositoryProvider)),
);
