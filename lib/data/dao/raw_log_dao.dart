import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../app_database.dart';

/// SQL của bảng nhật ký thông báo thô.
class RawLogDao {
  RawLogDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  Future<void> insert(RawLog log) async {
    final db = await _database;
    await db.insert(
      Tables.rawLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RawLog>> recent({int limit = 300}) async {
    final db = await _database;
    final rows = await db.query(
      Tables.rawLogs,
      orderBy: 'post_time DESC',
      limit: limit,
    );
    return rows.map(RawLog.fromMap).toList();
  }

  Future<List<RawLog>> forPackage(String packageName) async {
    final db = await _database;
    final rows = await db.query(
      Tables.rawLogs,
      where: 'package_name = ?',
      whereArgs: [packageName],
      orderBy: 'post_time DESC',
    );
    return rows.map(RawLog.fromMap).toList();
  }

  /// Tổng kết theo app gửi: bao nhiêu thông báo, lần cuối lúc nào, nội dung
  /// mới nhất ra sao. Màn cấu hình cần cả những app parser chưa đọc nổi, nên
  /// không thể chỉ nhìn bảng nguồn.
  Future<List<({String packageName, int count, DateTime lastAt, String lastContent})>>
  packages() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT r.package_name AS package_name,
             COUNT(*) AS cnt,
             MAX(r.post_time) AS last_at,
             (SELECT x.content FROM ${Tables.rawLogs} x
              WHERE x.package_name = r.package_name
              ORDER BY x.post_time DESC LIMIT 1) AS last_content
      FROM ${Tables.rawLogs} r
      GROUP BY r.package_name
      ORDER BY cnt DESC
    ''');
    return rows
        .map(
          (r) => (
            packageName: r['package_name'] as String,
            count: (r['cnt'] as int?) ?? 0,
            lastAt: DateTime.fromMillisecondsSinceEpoch(
              (r['last_at'] as int?) ?? 0,
            ),
            lastContent: r['last_content'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<void> markParsed(int id) async {
    final db = await _database;
    await db.update(
      Tables.rawLogs,
      {'parsed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBefore(DateTime cutoff) async {
    final db = await _database;
    await db.delete(
      Tables.rawLogs,
      where: 'post_time < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
