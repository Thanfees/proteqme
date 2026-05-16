import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hive_contact_repository.dart';

class DeleteContactUseCase {
  const DeleteContactUseCase(this._repository);

  final HiveContactRepository _repository;

  Future<void> call(String id) {
    return _repository.deleteContact(id);
  }
}

final deleteContactUseCaseProvider = Provider<DeleteContactUseCase>(
  (ref) => DeleteContactUseCase(ref.watch(hiveContactRepositoryProvider)),
);
