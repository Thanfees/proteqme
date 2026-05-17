import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../services/convex_service.dart';
import '../data/session_store.dart';

/// Snapshot of an authenticated user as the rest of the app sees it.
@immutable
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.token,
    required this.displayName,
    this.username,
  });

  final String userId;
  final String token;
  final String displayName;
  final String? username;

  AuthSession copyWith({String? displayName, String? username}) => AuthSession(
        userId: userId,
        token: token,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
      );
}

/// Owns the active [AuthSession] for the app.
///
/// `null` data state ⇒ logged out.  Errors surface as `AsyncError` and are
/// surfaced as snackbars in the UI; recoverable errors (e.g. transient
/// network) never throw away the cached session.
class AuthSessionNotifier extends AsyncNotifier<AuthSession?> {
  late final SessionStore _store = ref.read(sessionStoreProvider);

  @override
  Future<AuthSession?> build() async {
    // Initial state is "unknown" until restoreFromStorage runs.  We return
    // null so the app boots straight to the auth screen if storage is empty;
    // a background validateSession() then upgrades the state on success.
    final record = await _store.read();
    if (record == null) return null;
    // Mirror the cached display name into the local DB so SOS SMS continues
    // to use it even before we hit the network.
    unawaited(_mirrorDisplayName(record.displayName));
    return AuthSession(
      userId: record.userId,
      token: record.token,
      displayName: record.displayName,
      username: record.username,
    );
  }

  Future<void> _mirrorDisplayName(String name) async {
    try {
      final db = await AppDatabase.instance();
      await db.setUserDisplayName(name);
      await db.db.update(
        'auth_session',
        {'user_id': null, 'display_name': name},
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      debugPrint('AuthSession: failed to mirror display name: $e');
    }
  }

  Future<void> _writeLegacyAuthRow({
    required String userId,
    required String displayName,
    String? phone,
  }) async {
    try {
      final db = await AppDatabase.instance();
      await db.db.update(
        'auth_session',
        {
          'user_id': userId,
          'phone': phone,
          'display_name': displayName,
        },
        where: 'id = ?',
        whereArgs: [1],
      );
      await db.setUserDisplayName(displayName);
    } catch (e) {
      debugPrint('AuthSession: legacy auth_session write failed: $e');
    }
  }

  /// Called at app launch.  Cheap: reads the cached session synchronously
  /// and kicks off a background validation roundtrip that may sign the user
  /// out if the token is stale.
  Future<void> restoreFromStorage() async {
    state = const AsyncValue.loading();
    try {
      final record = await _store.read();
      if (record == null) {
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.data(
        AuthSession(
          userId: record.userId,
          token: record.token,
          displayName: record.displayName,
          username: record.username,
        ),
      );
      unawaited(_mirrorDisplayName(record.displayName));
      unawaited(_validateInBackground(record.token));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _validateInBackground(String token) async {
    final convex = ref.read(convexServiceProvider);
    if (convex == null) return;
    try {
      final result = await convex.validateSession(token);
      if (result == null) {
        debugPrint('AuthSession: server reports token invalid — signing out');
        await _store.clear();
        state = const AsyncValue.data(null);
        return;
      }
      final displayName = result['displayName'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        final current = state.valueOrNull;
        if (current != null && current.displayName != displayName) {
          await _store.updateDisplayName(displayName);
          state = AsyncValue.data(current.copyWith(displayName: displayName));
          unawaited(_mirrorDisplayName(displayName));
        }
      }
    } catch (e) {
      // Network failures are not fatal — keep the cached session.
      debugPrint('AuthSession: background validate failed: $e');
    }
  }

  Future<void> signup({
    required String username,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    final convex = ref.read(convexServiceProvider);
    if (convex == null) {
      throw StateError(
        'Cloud vault is not configured. '
        'Run with --dart-define=CONVEX_URL=... and CONVEX_DEPLOY_KEY=...',
      );
    }

    state = const AsyncValue.loading();
    try {
      final result = await convex.signup(
        username: username,
        password: password,
        displayName: displayName,
        phone: phone,
      );
      if (result == null) throw StateError('Empty signup response');
      final userId = result['userId'] as String?;
      final token = result['token'] as String?;
      final name = (result['displayName'] as String?) ?? displayName;
      if (userId == null || token == null) {
        throw StateError('Invalid signup response: missing userId or token');
      }
      await _store.save(
        userId: userId,
        token: token,
        displayName: name,
        username: username.toLowerCase(),
      );
      await _writeLegacyAuthRow(
        userId: userId,
        displayName: name,
        phone: phone,
      );
      state = AsyncValue.data(
        AuthSession(
          userId: userId,
          token: token,
          displayName: name,
          username: username.toLowerCase(),
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signin({
    required String username,
    required String password,
  }) async {
    final convex = ref.read(convexServiceProvider);
    if (convex == null) {
      throw StateError(
        'Cloud vault is not configured. '
        'Run with --dart-define=CONVEX_URL=... and CONVEX_DEPLOY_KEY=...',
      );
    }

    state = const AsyncValue.loading();
    try {
      final result = await convex.signin(
        username: username,
        password: password,
      );
      if (result == null) throw StateError('Empty signin response');
      final userId = result['userId'] as String?;
      final token = result['token'] as String?;
      final name = (result['displayName'] as String?) ?? 'ProteqMe User';
      if (userId == null || token == null) {
        throw StateError('Invalid signin response: missing userId or token');
      }
      await _store.save(
        userId: userId,
        token: token,
        displayName: name,
        username: username.toLowerCase(),
      );
      await _writeLegacyAuthRow(userId: userId, displayName: name);
      state = AsyncValue.data(
        AuthSession(
          userId: userId,
          token: token,
          displayName: name,
          username: username.toLowerCase(),
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signout() async {
    final current = state.valueOrNull;
    final convex = ref.read(convexServiceProvider);

    if (current != null && convex != null) {
      try {
        await convex.signout(current.token);
      } catch (e) {
        debugPrint('AuthSession: server signout failed (continuing): $e');
      }
    }

    await _store.clear();
    try {
      final db = await AppDatabase.instance();
      await db.db.update(
        'auth_session',
        {'user_id': null, 'phone': null},
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      debugPrint('AuthSession: legacy auth_session clear failed: $e');
    }
    state = const AsyncValue.data(null);
  }

  /// Update the display name remotely first, then mirror locally.  Falls back
  /// to local-only if Convex is unreachable so the user never gets stuck.
  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Display name cannot be empty');

    final current = state.valueOrNull;
    final convex = ref.read(convexServiceProvider);

    if (current != null && convex != null) {
      try {
        await convex.updateProfile(
          token: current.token,
          displayName: trimmed,
        );
      } catch (e) {
        debugPrint('AuthSession: updateProfile failed (still saving local): $e');
      }
    }

    try {
      final db = await AppDatabase.instance();
      await db.setUserDisplayName(trimmed);
      await db.db.update(
        'auth_session',
        {'display_name': trimmed},
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      debugPrint('AuthSession: local display name write failed: $e');
    }

    if (current != null) {
      await _store.updateDisplayName(trimmed);
      state = AsyncValue.data(current.copyWith(displayName: trimmed));
    }
  }

}

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
  AuthSessionNotifier.new,
);
