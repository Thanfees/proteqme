import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/session_store.dart';
import '../features/contacts/data/hive_contact_repository.dart';
import '../features/contacts/domain/entities/emergency_contact.dart';
import 'convex_service.dart';

/// Bridges local Hive contact storage with the Convex cloud backend.
///
/// All cloud operations are **best-effort**: failures are logged but never
/// surface to the user.  The local Hive store remains the source of truth for
/// the UI, and Convex acts as a durable backup + cross-device sync layer.
class ContactSyncService {
  const ContactSyncService({
    required ConvexService? convex,
    required SessionStore sessionStore,
    required HiveContactRepository localRepo,
  })  : _convex = convex,
        _sessionStore = sessionStore,
        _localRepo = localRepo;

  final ConvexService? _convex;
  final SessionStore _sessionStore;
  final HiveContactRepository _localRepo;

  // ──────────────── Single-contact mutations ────────────────

  /// Push a newly-added or updated contact to Convex.
  Future<void> pushContact(EmergencyContact contact) async {
    final convex = _convex;
    if (convex == null) return;
    final session = await _sessionStore.read();
    if (session == null) return;

    try {
      await convex.addContact(
        token: session.token,
        name: contact.name,
        phone: contact.phone,
        priority: contact.isPrimary ? 1 : 0,
        language: contact.language,
      );
      debugPrint('ContactSync: pushed ${contact.name} to cloud');
    } catch (e) {
      debugPrint('ContactSync: push failed for ${contact.name}: $e');
    }
  }

  /// Remove a contact from Convex by finding its cloud record by phone number.
  Future<void> removeContact(EmergencyContact contact) async {
    final convex = _convex;
    if (convex == null) return;
    final session = await _sessionStore.read();
    if (session == null) return;

    try {
      // Fetch remote contacts to find the matching document ID.
      final remote = await convex.fetchContacts(token: session.token);
      for (final row in remote) {
        if (row['phone'] == contact.phone) {
          final cid = row['_id']?.toString();
          if (cid != null) {
            await convex.deleteContact(
              contactId: cid,
              token: session.token,
            );
            debugPrint('ContactSync: removed ${contact.name} from cloud');
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('ContactSync: remove failed for ${contact.name}: $e');
    }
  }

  // ──────────────── Full sync (sign-in / sign-up) ───────────

  /// Performs a bidirectional merge:
  /// 1. Pulls remote contacts into local Hive (skips duplicates by phone).
  /// 2. Pushes all local contacts to Convex via upsertBatch.
  Future<void> fullSync() async {
    final convex = _convex;
    if (convex == null) return;
    final session = await _sessionStore.read();
    if (session == null) return;

    try {
      // ── Pull: cloud → local ──
      final remote = await convex.fetchContacts(token: session.token);
      final localContacts = await _localRepo.getContacts();
      final localPhones = <String>{
        for (final c in localContacts) c.phone,
      };

      for (final row in remote) {
        final phone = row['phone'] as String? ?? '';
        if (phone.isEmpty || localPhones.contains(phone)) continue;

        await _localRepo.upsertContact(
          EmergencyContact(
            id: row['_id']?.toString() ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            name: row['name'] as String? ?? 'Contact',
            phone: phone,
            isPrimary: row['priority'] == 1,
            language: row['language'] as String? ?? 'en',
          ),
        );
        debugPrint('ContactSync: pulled $phone from cloud');
      }

      // ── Push: local → cloud (batch) ──
      final allLocal = await _localRepo.getContacts();
      if (allLocal.isNotEmpty) {
        final payload = allLocal
            .map((c) => {
                  'name': c.name,
                  'phone': c.phone,
                  'priority': c.isPrimary ? 1 : 0,
                  'language': c.language,
                })
            .toList();

        await convex.syncContacts(
          token: session.token,
          contacts: payload,
        );
        debugPrint('ContactSync: pushed ${allLocal.length} contacts to cloud');
      }
    } catch (e) {
      debugPrint('ContactSync: fullSync failed: $e');
    }
  }
}

final contactSyncServiceProvider = Provider<ContactSyncService>((ref) {
  return ContactSyncService(
    convex: ref.watch(convexServiceProvider),
    sessionStore: ref.watch(sessionStoreProvider),
    localRepo: ref.watch(hiveContactRepositoryProvider),
  );
});
