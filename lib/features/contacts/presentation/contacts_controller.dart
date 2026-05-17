import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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
    this._contactRepository,
  );

  final SaveContactUseCase _saveContact;
  final DeleteContactUseCase _deleteContact;
  final SetPrimaryContactUseCase _setPrimaryContact;
  final HiveContactRepository _contactRepository;

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

  /// Open the native contact picker and add the selected person
  /// as an emergency contact.
  Future<PickResult> pickFromPhone() async {
    // Request via permission_handler first so we can detect permanent denial.
    final status = await Permission.contacts.request();

    if (status.isPermanentlyDenied) {
      return const PickResult(
        error:
            'Contacts permission permanently denied. Open Settings and allow Contacts.',
        openSettings: true,
      );
    }

    if (!status.isGranted) {
      return const PickResult(
        error: 'Contacts permission denied. Tap again to retry.',
      );
    }

    // Open the OS contact picker — user selects ONE contact.
    Contact? picked;
    try {
      picked = await FlutterContacts.openExternalPick();
    } catch (e) {
      return PickResult(error: 'Failed to open contact picker: $e');
    }

    if (picked == null) {
      // User cancelled the picker.
      return const PickResult(cancelled: true);
    }

    // Re-fetch the full contact with phone numbers.
    Contact? full;
    try {
      full = await FlutterContacts.getContact(picked.id, withProperties: true);
    } catch (e) {
      return PickResult(error: 'Failed to read contact details: $e');
    }

    if (full == null || full.phones.isEmpty) {
      return const PickResult(
        error: 'Selected contact has no phone number.',
      );
    }

    final phone =
        full.phones.first.number.replaceAll(RegExp(r'[\s\-]'), '');

    if (!PhoneValidator.isValid(phone)) {
      return const PickResult(
        error: 'Selected contact has an invalid phone number.',
      );
    }

    final name = full.displayName.trim().isEmpty
        ? phone
        : full.displayName.trim();

    // Check if this number is already in the emergency list.
    final existing = await _contactRepository.getContacts();
    for (final c in existing) {
      if (c.phone == phone) {
        return PickResult(
          error: '$name is already in your emergency contacts.',
        );
      }
    }

    final hasPrimary = existing.any((c) => c.isPrimary);

    await _saveContact(
      EmergencyContact(
        id: '${full.id}_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        phone: phone,
        isPrimary: !hasPrimary, // first contact becomes primary
      ),
    );

    return PickResult(addedName: name);
  }
}

class PickResult {
  const PickResult({
    this.addedName,
    this.error,
    this.openSettings = false,
    this.cancelled = false,
  });

  /// Name of the contact that was added (null on failure/cancel).
  final String? addedName;
  final String? error;
  final bool openSettings;
  final bool cancelled;
}

final contactsControllerProvider = Provider<ContactsController>(
  (ref) => ContactsController(
    ref.watch(saveContactUseCaseProvider),
    ref.watch(deleteContactUseCaseProvider),
    ref.watch(setPrimaryContactUseCaseProvider),
    ref.watch(hiveContactRepositoryProvider),
  ),
);
