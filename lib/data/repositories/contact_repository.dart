import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/contact.dart';

class ContactRepository {
  ContactRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Contact>> getAll() async {
    final db = await _database.database;
    final rows = await db.query(
      'contacts',
      orderBy: 'priority ASC',
    );
    return rows.map(Contact.fromMap).toList();
  }

  Future<Contact?> getById(int id) async {
    final db = await _database.database;
    final rows = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Contact.fromMap(rows.first);
  }

  Future<int> insert(Contact contact) async {
    final db = await _database.database;
    return db.insert('contacts', contact.toMap());
  }

  Future<void> update(Contact contact) async {
    final db = await _database.database;
    await db.update(
      'contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAll(List<Contact> contacts) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('contacts');
      for (final c in contacts) {
        await txn.insert('contacts', c.toMap());
      }
    });
  }

  Future<int> count() async {
    final db = await _database.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as c FROM contacts');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
