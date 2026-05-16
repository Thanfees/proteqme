import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Versioned SQLite database for offline-first SOS state.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int _version = 1;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'proteqme.db');
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        priority INTEGER NOT NULL UNIQUE,
        language TEXT NOT NULL DEFAULT 'en',
        convex_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sos_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        is_active INTEGER NOT NULL DEFAULT 0,
        triggered_at INTEGER,
        user_name TEXT NOT NULL DEFAULT '',
        sms_interval_sec INTEGER NOT NULL DEFAULT 360,
        call_paused INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.insert('sos_state', {
      'id': 1,
      'is_active': 0,
      'user_name': '',
      'sms_interval_sec': 360,
      'call_paused': 0,
    });

    await db.execute('''
      CREATE TABLE gps_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy REAL,
        source TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE call_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contact_id INTEGER,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        duration_sec INTEGER,
        outcome TEXT NOT NULL,
        FOREIGN KEY (contact_id) REFERENCES contacts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_sync (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations here.
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
