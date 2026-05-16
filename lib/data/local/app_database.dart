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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sos_state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            is_active INTEGER NOT NULL DEFAULT 0,
            user_name TEXT NOT NULL DEFAULT 'ProteqMe User',
            sms_interval_sec INTEGER NOT NULL DEFAULT 360,
            call_paused INTEGER NOT NULL DEFAULT 0,
            triggered_at_ms INTEGER
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
