import '../entities/emergency_contact.dart';

abstract class ContactRepository {
  Future<List<EmergencyContact>> getContacts();

  Stream<List<EmergencyContact>> watchContacts();

  Future<EmergencyContact?> getPrimaryContact();

  Future<void> upsertContact(EmergencyContact contact);

  Future<void> deleteContact(String id);

  Future<void> setPrimary(String id);
}
