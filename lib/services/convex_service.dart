import 'dart:convert';

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

  Future<Map<String, dynamic>?> requestOtp(String phone) async {
    return _mutation('auth:requestOtp', {'phone': phone});
  }

  Future<Map<String, dynamic>?> verifyOtp({
    required String phone,
    required String code,
  }) async {
    return _mutation('auth:verifyOtp', {'phone': phone, 'code': code});
  }

  Future<void> syncContacts({
    required String userId,
    required List<Map<String, dynamic>> contacts,
  }) async {
    await _mutation('contacts:upsertBatch', {
      'userId': userId,
      'contacts': contacts,
    });
  }

  Future<List<Map<String, dynamic>>> fetchContacts(String userId) async {
    final result = await _query('contacts:listByUser', {'userId': userId});
    if (result is List) {
      return result.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  Future<void> pushLiveLocation({
    required String userId,
    required double lat,
    required double lng,
    required bool sosActive,
  }) async {
    await _mutation('liveLocation:update', {
      'userId': userId,
      'lat': lat,
      'lng': lng,
      'sosActive': sosActive,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> recordSosEvent(Map<String, dynamic> payload) async {
    await _mutation('sosEvents:record', payload);
  }

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
