import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

/// Bảng khoá–giá trị cho những lựa chọn lặt vặt của user.
class SettingsDao {
  SettingsDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<String?> read(String key) async {
    final db = await _database;
    final rows = await db.query(
      Tables.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> write(String key, String value) async {
    final db = await _database;
    await db.insert(
      Tables.settings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
