import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/entities/emergency_contact.dart';
import '../domain/repositories/contact_repository.dart';

class HiveContactRepository implements ContactRepository {
  HiveContactRepository(this._box);

  final Box<EmergencyContact> _box;

  @override
  Future<void> deleteContact(String id) async {
    final deleted = _box.get(id);
    await _box.delete(id);

    if (deleted?.isPrimary == true) {
      final remaining = _sortedContacts();
      if (remaining.isNotEmpty) {
        await setPrimary(remaining.first.id);
      }
    }
  }

  @override
  Future<List<EmergencyContact>> getContacts() async {
    return _sortedContacts();
  }

  @override
  Future<EmergencyContact?> getPrimaryContact() async {
    final contacts = _sortedContacts();
    for (final contact in contacts) {
      if (contact.isPrimary) {
        return contact;
      }
    }
    return null;
  }

  @override
  Future<void> setPrimary(String id) async {
    final entries = _sortedContacts();
    final updates = <Future<void>>[];

    for (final contact in entries) {
      final shouldBePrimary = contact.id == id;
      if (contact.isPrimary != shouldBePrimary) {
        updates.add(
          _box.put(contact.id, contact.copyWith(isPrimary: shouldBePrimary)),
        );
      }
    }

    await Future.wait(updates);
  }

  @override
  Future<void> upsertContact(EmergencyContact contact) async {
    await _box.put(contact.id, contact);

    if (contact.isPrimary) {
      await setPrimary(contact.id);
      return;
    }

    final primary = await getPrimaryContact();
    if (primary == null) {
      await setPrimary(contact.id);
    }
  }

  @override
  Stream<List<EmergencyContact>> watchContacts() {
    return _box
        .watch()
        .map((_) => _sortedContacts())
        .startWith(_sortedContacts());
  }

  List<EmergencyContact> _sortedContacts() {
    final contacts = _box.values.toList(growable: false);
    contacts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return contacts;
  }
}

final hiveContactRepositoryProvider = Provider<HiveContactRepository>(
  (ref) => HiveContactRepository(
    Hive.box<EmergencyContact>(AppConstants.contactsBoxName),
  ),
);

extension _StartWithExtension<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
