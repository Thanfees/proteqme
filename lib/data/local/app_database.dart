import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite for SOS state, GPS trail, and Convex pending sync.
class AppDatabase {
  AppDatabase._();
  static AppDatabase? _instance;
  static Database? _db;

  static Future<AppDatabase> instance() async {
    if (_instance != null) return _instance!;
    _instance = AppDatabase._();
    _db = await _open();
    return _instance!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'proteqme.db'),
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Best-effort additive migration: add the biometric lock column to
          // existing installs.  Wrapped in try/catch so a partially-migrated
          // schema (e.g. column already added in dev) does not crash boot.
          try {
            await db.execute(
              'ALTER TABLE sos_state ADD COLUMN biometric_lock INTEGER NOT NULL DEFAULT 1',
            );
          } catch (_) {
            // Column already exists — safe to ignore.
          }
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sos_state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            is_active INTEGER NOT NULL DEFAULT 0,
            user_name TEXT NOT NULL DEFAULT 'ProteqMe User',
            sms_interval_sec INTEGER NOT NULL DEFAULT 360,
            call_paused INTEGER NOT NULL DEFAULT 0,
            triggered_at_ms INTEGER,
            biometric_lock INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.insert('sos_state', {'id': 1});

        await db.execute('''
          CREATE TABLE gps_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp_ms INTEGER NOT NULL,
            lat REAL NOT NULL,
            lng REAL NOT NULL,
            source TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_sync (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload_json TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE auth_session (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            user_id TEXT,
            phone TEXT,
            display_name TEXT
          )
        ''');
        await db.insert('auth_session', {'id': 1});
      },
    );
  }

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('AppDatabase not initialized');
    }
    return database;
  }

  Future<void> setSosActive({
    required bool active,
    String userName = 'ProteqMe User',
    int smsIntervalSec = 360,
  }) async {
    await db.update(
      'sos_state',
      {
        'is_active': active ? 1 : 0,
        'user_name': userName,
        'sms_interval_sec': smsIntervalSec,
        'triggered_at_ms': active ? DateTime.now().millisecondsSinceEpoch : null,
        'call_paused': 0,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<bool> isSosActive() async {
    final rows = await db.query('sos_state', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return false;
    return (rows.first['is_active'] as int? ?? 0) == 1;
  }

  /// User's display name used in outgoing SOS SMS.
  Future<String> getUserDisplayName() async {
    final rows = await db.query(
      'sos_state',
      columns: ['user_name'],
      where: 'id = ?',
      whereArgs: [1],
    );
    final name = rows.isEmpty ? null : rows.first['user_name'] as String?;
    return (name?.trim().isNotEmpty == true) ? name!.trim() : 'ProteqMe User';
  }

  Future<void> setUserDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await db.update(
      'sos_state',
      {'user_name': trimmed},
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  /// Whether the launch-time biometric gate should challenge the user.
  /// Defaults to ON (1) for any new install and any signed-in account.
  Future<bool> getBiometricLockEnabled() async {
    try {
      final rows = await db.query(
        'sos_state',
        columns: ['biometric_lock'],
        where: 'id = ?',
        whereArgs: [1],
      );
      if (rows.isEmpty) return true;
      final v = rows.first['biometric_lock'] as int?;
      return (v ?? 1) == 1;
    } catch (_) {
      // Column may not exist yet (e.g. very old install where the migration
      // failed) — default to locked for safety.
      return true;
    }
  }

  Future<void> setBiometricLockEnabled(bool enabled) async {
    try {
      await db.update(
        'sos_state',
        {'biometric_lock': enabled ? 1 : 0},
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (_) {
      // If the column is missing for some reason, add it and retry once.
      try {
        await db.execute(
          'ALTER TABLE sos_state ADD COLUMN biometric_lock INTEGER NOT NULL DEFAULT 1',
        );
        await db.update(
          'sos_state',
          {'biometric_lock': enabled ? 1 : 0},
          where: 'id = ?',
          whereArgs: [1],
        );
      } catch (_) {
        // Give up silently — toggle is a UX preference, not safety-critical.
      }
    }
  }

  Future<void> appendGpsLog({
    required double lat,
    required double lng,
    required String source,
  }) async {
    await db.insert('gps_log', {
      'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      'lat': lat,
      'lng': lng,
      'source': source,
    });
  }

  Future<void> queuePendingSync(String payloadJson) async {
    await db.insert('pending_sync', {
      'payload_json': payloadJson,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
