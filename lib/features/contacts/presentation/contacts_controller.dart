import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/phone_validator.dart';
import '../domain/entities/emergency_contact.dart';
import '../domain/usecases/delete_contact_usecase.dart';
import '../domain/usecases/save_contact_usecase.dart';
import '../domain/usecases/set_primary_contact_usecase.dart';
import '../data/hive_contact_repository.dart';

final contactsProvider = StreamProvider<List<EmergencyContact>>(
  (ref) => ref.watch(hiveContactRepositoryProvider).watchContacts(),
);

final primaryContactProvider = Provider<EmergencyContact?>((ref) {
  final contactsState = ref.watch(contactsProvider);
  return contactsState.maybeWhen(
    data: (contacts) {
      for (final contact in contacts) {
        if (contact.isPrimary) {
          return contact;
        }
      }
      return null;
    },
    orElse: () => null,
  );
});

class ContactsController {
  const ContactsController(
    this._saveContact,
    this._deleteContact,
    this._setPrimaryContact,
  );

  final SaveContactUseCase _saveContact;
  final DeleteContactUseCase _deleteContact;
  final SetPrimaryContactUseCase _setPrimaryContact;

  Future<String?> addContact({
    required String name,
    required String phone,
    required bool setAsPrimary,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    if (trimmedName.isEmpty) {
      return 'Name is required.';
    }

    if (!PhoneValidator.isValid(trimmedPhone)) {
      return 'Phone number must contain only digits with optional + prefix.';
    }

    final contact = EmergencyContact(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmedName,
      phone: trimmedPhone,
      isPrimary: setAsPrimary,
    );

    await _saveContact(contact);
    return null;
  }

  Future<String?> updateContact({
    required EmergencyContact contact,
    required String name,
    required String phone,
    required bool setAsPrimary,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    if (trimmedName.isEmpty) {
      return 'Name is required.';
    }

    if (!PhoneValidator.isValid(trimmedPhone)) {
      return 'Phone number must contain only digits with optional + prefix.';
    }

    final updated = contact.copyWith(
      name: trimmedName,
      phone: trimmedPhone,
      isPrimary: setAsPrimary,
    );

    await _saveContact(updated);
    return null;
  }

  Future<void> deleteContact(String id) {
    return _deleteContact(id);
  }

  Future<void> setPrimary(String id) {
    return _setPrimaryContact(id);
  }
}

final contactsControllerProvider = Provider<ContactsController>(
  (ref) => ContactsController(
    ref.watch(saveContactUseCaseProvider),
    ref.watch(deleteContactUseCaseProvider),
    ref.watch(setPrimaryContactUseCaseProvider),
  ),
);
