// convex_dart exposes client via src/ — required for encode/decode helpers.
// ignore_for_file: implementation_imports

import 'package:convex_dart/src/encode.dart';
import 'package:convex_dart/src/internal_convex_client.dart';

import '../core/config/secrets.dart';
import '../data/models/contact.dart';

/// Convex client — setup sync and post-incident upload only (never SOS hot path).
class ConvexService {
  ConvexService._();
  static final ConvexService instance = ConvexService._();

  InternalConvexClient? _client;
  bool _initialized = false;

  bool get isConfigured => Secrets.hasConvex;

  Future<InternalConvexClient> _ensureClient() async {
    if (!isConfigured) {
      throw StateError('Convex not configured. Set CONVEX_URL and CONVEX_DEPLOY_KEY.');
    }
    if (!_initialized) {
      _client = await InternalConvexClient.init(
        deploymentUrl: Secrets.convexUrl,
      );
      _initialized = true;
    }
    return _client!;
  }

  Future<List<Contact>> fetchContacts(String userId) async {
    if (!isConfigured) return [];
    final client = await _ensureClient();
    final result = await client.query(
      name: 'contacts:listByUser',
      args: encodeMap({'userId': userId}),
    );
    final decoded = decodeValue(result);
    if (decoded is! Iterable) return [];
    return decoded.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return Contact(
        name: map['name'] as String,
        phone: map['phone'] as String,
        priority: map['priority'] as int,
        language: map['language'] as String? ?? 'en',
        convexId: map['_id']?.toString(),
      );
    }).toList();
  }

  Future<void> upsertContacts(String userId, List<Contact> contacts) async {
    if (!isConfigured) return;
    final client = await _ensureClient();
    await client.mutation(
      name: 'contacts:upsertBatch',
      args: encodeMap({
        'userId': userId,
        'contacts': contacts
            .map(
              (c) => {
                'name': c.name,
                'phone': c.phone,
                'priority': c.priority,
                'language': c.language,
              },
            )
            .toList(),
      }),
    );
  }

  Future<void> recordSosEvent(Map<String, dynamic> payload) async {
    if (!isConfigured) return;
    final client = await _ensureClient();
    await client.mutation(
      name: 'sos_events:record',
      args: encodeMap(payload),
    );
  }
}
