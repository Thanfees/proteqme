import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/config/secrets.dart';

/// Convex vault via HTTP API (auth, contacts, live location, incident logs).
class ConvexService {
  ConvexService({required this.baseUrl, this.deployKey = ''});

  final String baseUrl;
  final String deployKey;

  static ConvexService? tryCreate() {
    if (!Secrets.hasConvex) return null;
    return ConvexService(
      baseUrl: Secrets.convexUrl,
      deployKey: Secrets.convexDeployKey,
    );
  }

  // ──────────────────────────── Auth ────────────────────────────

  Future<Map<String, dynamic>?> requestOtp(String phone) async {
    return _mutation('auth:requestOtp', {'phone': phone});
  }

  Future<Map<String, dynamic>?> verifyOtp({
    required String phone,
    required String code,
  }) async {
    return _mutation('auth:verifyOtp', {'phone': phone, 'code': code});
  }

  /// Hashes the raw password client-side so we never send it in cleartext —
  /// the server then re-hashes with its own per-user salt for storage.
  static String _clientHashPassword(String password) {
    return sha256.convert(utf8.encode('proteqme:$password')).toString();
  }

  Future<Map<String, dynamic>?> signup({
    required String username,
    required String password,
    required String displayName,
    String? phone,
    String? deviceLabel,
  }) async {
    return _mutation('auth:signup', {
      'username': username,
      'password': _clientHashPassword(password),
      'displayName': displayName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (deviceLabel != null && deviceLabel.isNotEmpty)
        'deviceLabel': deviceLabel,
    });
  }

  Future<Map<String, dynamic>?> signin({
    required String username,
    required String password,
    String? deviceLabel,
  }) async {
    return _mutation('auth:signin', {
      'username': username,
      'password': _clientHashPassword(password),
      if (deviceLabel != null && deviceLabel.isNotEmpty)
        'deviceLabel': deviceLabel,
    });
  }

  Future<void> signout(String token) async {
    await _mutation('auth:signout', {'token': token});
  }

  /// Returns `{userId, displayName}` on success, or `null` if the token is no
  /// longer valid server-side.
  Future<Map<String, dynamic>?> validateSession(String token) async {
    return _mutation('auth:validateSession', {'token': token});
  }

  Future<Map<String, dynamic>?> updateProfile({
    required String token,
    String? displayName,
    String? phone,
  }) async {
    return _mutation('auth:updateProfile', {
      'token': token,
      if (displayName != null) 'displayName': displayName,
      if (phone != null) 'phone': phone,
    });
  }

  // ──────────────────────── Contacts ───────────────────────────

  /// Fetch all contacts for a session token.  Falls back to userId for the
  /// legacy OTP path when no token is available.
  Future<List<Map<String, dynamic>>> fetchContacts({
    String? token,
    String? userId,
  }) async {
    final args = <String, dynamic>{};
    if (token != null) args['token'] = token;
    if (userId != null) args['userId'] = userId;
    final result = await _query('contacts:listByUser', args);
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  /// Add a single contact (manual entry or single phone-book pick).
  Future<Map<String, dynamic>?> addContact({
    String? token,
    String? userId,
    required String name,
    required String phone,
    required int priority,
    required String language,
  }) async {
    final args = <String, dynamic>{
      'name': name,
      'phone': phone,
      'priority': priority,
      'language': language,
    };
    if (token != null) args['token'] = token;
    if (userId != null) args['userId'] = userId;
    return _mutation('contacts:addOne', args);
  }

  /// Update an existing contact by its Convex document ID.
  Future<Map<String, dynamic>?> updateContact({
    required String contactId,
    String? token,
    String? userId,
    String? name,
    String? phone,
    int? priority,
    String? language,
  }) async {
    final args = <String, dynamic>{'contactId': contactId};
    if (token != null) args['token'] = token;
    if (userId != null) args['userId'] = userId;
    if (name != null) args['name'] = name;
    if (phone != null) args['phone'] = phone;
    if (priority != null) args['priority'] = priority;
    if (language != null) args['language'] = language;
    return _mutation('contacts:updateOne', args);
  }

  /// Delete a single contact by its Convex document ID.
  Future<Map<String, dynamic>?> deleteContact({
    required String contactId,
    String? token,
    String? userId,
  }) async {
    final args = <String, dynamic>{'contactId': contactId};
    if (token != null) args['token'] = token;
    if (userId != null) args['userId'] = userId;
    return _mutation('contacts:deleteOne', args);
  }

  /// Batch-replace all contacts for a user (phone-book import).  Returns the
  /// list of inserted Convex IDs in input order so the caller can persist
  /// them locally.
  Future<List<String>> syncContacts({
    String? token,
    String? userId,
    required List<Map<String, dynamic>> contacts,
  }) async {
    final args = <String, dynamic>{'contacts': contacts};
    if (token != null) args['token'] = token;
    if (userId != null) args['userId'] = userId;
    final result = await _mutation('contacts:upsertBatch', args);
    final ids = result?['ids'];
    if (ids is List) {
      return ids.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  // ────────────────────── Live Location ────────────────────────

  Future<void> pushLiveLocation({
    String? token,
    String? userId,
    required double lat,
    required double lng,
    required bool sosActive,
  }) async {
    final args = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'sosActive': sosActive,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    };
    if (token != null) args['token'] = token;
    if (userId != null) args['userId'] = userId;
    await _mutation('liveLocation:update', args);
  }

  // ──────────────────────── SOS Events ─────────────────────────

  Future<void> recordSosEvent(Map<String, dynamic> payload) async {
    await _mutation('sosEvents:record', payload);
  }

  // ──────────────────────── Internals ──────────────────────────

  Future<dynamic> _query(String name, Map<String, dynamic> args) async {
    final response = await _post('/api/query', name, args);
    return response?['value'];
  }

  Future<Map<String, dynamic>?> _mutation(
    String name,
    Map<String, dynamic> args,
  ) async {
    final response = await _post('/api/mutation', name, args);
    final value = response?['value'];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _post(
    String path,
    String functionName,
    Map<String, dynamic> args,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (deployKey.isNotEmpty) {
      headers['Authorization'] = 'Convex $deployKey';
    }

    final body = jsonEncode({
      'path': functionName,
      'args': args,
      'format': 'json',
    });

    final response = await http.post(uri, headers: headers, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Convex HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }
}

final convexServiceProvider = Provider<ConvexService?>((ref) {
  return ConvexService.tryCreate();
});
