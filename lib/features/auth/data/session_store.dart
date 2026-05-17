import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Snapshot of the persisted session record returned by [SessionStore.read].
typedef SessionRecord = ({
  String userId,
  String token,
  String displayName,
  String? username,
});

/// Encrypted persistence for the Convex session token + cached identity bits.
///
/// Survives reinstalls only on platforms where the underlying keystore is
/// backed up (Android, by default). On unsupported platforms the storage is
/// simply scoped to the app sandbox.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  final _controller = StreamController<bool>.broadcast();
  SessionRecord? _cached;
  bool _loaded = false;

  static const _kUserId = 'auth.userId';
  static const _kToken = 'auth.token';
  static const _kDisplayName = 'auth.displayName';
  static const _kUsername = 'auth.username';

  /// Reactive stream of "is logged in?".  Replays the last known value on
  /// subscription so consumers (e.g. the biometric gate) get the current
  /// state immediately.
  Stream<bool> get isLoggedIn async* {
    if (_loaded) yield _cached != null;
    yield* _controller.stream;
  }

  Future<void> save({
    required String userId,
    required String token,
    required String displayName,
    String? username,
  }) async {
    await Future.wait([
      _storage.write(key: _kUserId, value: userId),
      _storage.write(key: _kToken, value: token),
      _storage.write(key: _kDisplayName, value: displayName),
      if (username != null && username.isNotEmpty)
        _storage.write(key: _kUsername, value: username)
      else
        _storage.delete(key: _kUsername),
    ]);
    _cached = (
      userId: userId,
      token: token,
      displayName: displayName,
      username: username,
    );
    _loaded = true;
    _controller.add(true);
  }

  Future<SessionRecord?> read() async {
    try {
      final results = await Future.wait([
        _storage.read(key: _kUserId),
        _storage.read(key: _kToken),
        _storage.read(key: _kDisplayName),
        _storage.read(key: _kUsername),
      ]);
      final userId = results[0];
      final token = results[1];
      if (userId == null || token == null) {
        _cached = null;
        _loaded = true;
        _controller.add(false);
        return null;
      }
      _cached = (
        userId: userId,
        token: token,
        displayName: results[2] ?? 'ProteqMe User',
        username: results[3],
      );
      _loaded = true;
      _controller.add(true);
      return _cached;
    } catch (e) {
      debugPrint('SessionStore.read failed: $e');
      _cached = null;
      _loaded = true;
      _controller.add(false);
      return null;
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kToken),
      _storage.delete(key: _kDisplayName),
      _storage.delete(key: _kUsername),
    ]);
    _cached = null;
    _loaded = true;
    _controller.add(false);
  }

  /// Update only the cached display name without rotating the token.
  Future<void> updateDisplayName(String displayName) async {
    final current = _cached;
    if (current == null) return;
    await _storage.write(key: _kDisplayName, value: displayName);
    _cached = (
      userId: current.userId,
      token: current.token,
      displayName: displayName,
      username: current.username,
    );
    _controller.add(true);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final store = SessionStore();
  ref.onDispose(() => store.dispose());
  return store;
});
