import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../app_database.dart';

/// SQL của bảng mẫu bóc tách riêng cho từng ngân hàng.
class ParserProfileDao {
  ParserProfileDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<List<ParserProfile>> all() async {
    final db = await _database;
    final rows = await db.query(Tables.parserProfiles, orderBy: 'package_name');
    return rows.map(ParserProfile.fromMap).toList();
  }

  Future<ParserProfile?> byPackage(String packageName) async {
    final db = await _database;
    final rows = await db.query(
      Tables.parserProfiles,
      where: 'package_name = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    return rows.isEmpty ? null : ParserProfile.fromMap(rows.first);
  }

  Future<void> save(ParserProfile profile) async {
    final db = await _database;
    await db.insert(
      Tables.parserProfiles,
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String packageName) async {
    final db = await _database;
    await db.delete(
      Tables.parserProfiles,
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }
}
