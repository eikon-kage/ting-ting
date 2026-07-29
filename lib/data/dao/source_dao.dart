import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../app_database.dart';

/// SQL của bảng nguồn (app được coi là nguồn giao dịch).
class SourceDao {
  SourceDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<List<Source>> all() async {
    final db = await _database;
    final rows = await db.query(
      Tables.sources,
      orderBy: 'enabled DESC, display_name',
    );
    return rows.map(Source.fromMap).toList();
  }

  Future<Source?> byPackage(String packageName) async {
    final db = await _database;
    final rows = await db.query(
      Tables.sources,
      where: 'package_name = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    return rows.isEmpty ? null : Source.fromMap(rows.first);
  }

  Future<Set<String>> enabledPackages() async {
    final db = await _database;
    final rows = await db.query(
      Tables.sources,
      columns: ['package_name'],
      where: 'enabled = 1',
    );
    return rows.map((r) => r['package_name'] as String).toSet();
  }

  /// Không ghi đè nếu app đó đã có trong danh sách (giữ nguyên lựa chọn của
  /// user).
  Future<void> insertIfAbsent(Source source) async {
    final db = await _database;
    await db.insert(
      Tables.sources,
      source.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> setEnabled(String packageName, bool enabled) async {
    final db = await _database;
    await db.update(
      Tables.sources,
      {'enabled': enabled ? 1 : 0},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  Future<void> rename(String packageName, String displayName) async {
    final db = await _database;
    await db.update(
      Tables.sources,
      {'display_name': displayName},
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }
}
