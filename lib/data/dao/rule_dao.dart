import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../app_database.dart';

/// SQL của bảng quy tắc phân loại.
class RuleDao {
  RuleDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<List<Rule>> all() async {
    final db = await _database;
    final rows = await db.query(Tables.rules, orderBy: 'id DESC');
    return rows.map(Rule.fromMap).toList();
  }

  Future<void> insert(Rule rule) async {
    final db = await _database;
    await db.insert(Tables.rules, rule.toMap());
  }

  Future<void> deleteById(int id) async {
    final db = await _database;
    await db.delete(Tables.rules, where: 'id = ?', whereArgs: [id]);
  }

  /// Đổi tên hoặc xoá một nhóm thì các quy tắc đang trỏ vào đó phải theo,
  /// nếu không chúng sẽ xếp giao dịch vào một nhóm không còn tồn tại.
  Future<void> replaceCategory(String from, String to) async {
    final db = await _database;
    await db.update(
      Tables.rules,
      {'category': to},
      where: 'category = ?',
      whereArgs: [from],
    );
  }
}
