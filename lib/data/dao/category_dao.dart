import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../app_database.dart';

/// SQL của bảng nhóm chi tiêu.
class CategoryDao {
  CategoryDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<List<Category>> all() async {
    final db = await _database;
    final rows = await db.query(Tables.categories, orderBy: 'sort_order, id');
    return rows.map(Category.fromMap).toList();
  }

  /// Nhóm mới xếp xuống cuối danh sách.
  Future<int> insert(Category category) async {
    final db = await _database;
    final last =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT MAX(sort_order) FROM ${Tables.categories}'),
        ) ??
        0;
    return db.insert(
      Tables.categories,
      category.copyWith(sortOrder: last + 1).toMap(),
    );
  }

  Future<void> update(Category category) async {
    final db = await _database;
    await db.update(
      Tables.categories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteById(int id) async {
    final db = await _database;
    await db.delete(Tables.categories, where: 'id = ?', whereArgs: [id]);
  }
}
