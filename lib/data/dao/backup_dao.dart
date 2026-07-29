import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

/// Đọc và ghi thẳng từng bảng, không qua kiểu dữ liệu nào.
///
/// Các DAO khác dịch dòng SQL thành đối tượng nghiệp vụ; DAO này cố tình không
/// làm thế. Bản sao lưu phải chép được cả những cột mà bản app hiện tại chưa
/// biết đọc, nếu không thì nạp lại một file cũ hơn sẽ âm thầm làm mất cột.
class BackupDao {
  BackupDao(this._db);

  /// Mọi bảng có mặt trong một bản sao lưu đầy đủ, theo thứ tự an toàn để nạp.
  static const List<String> tables = [
    Tables.categories,
    Tables.rules,
    Tables.sources,
    Tables.parserProfiles,
    Tables.settings,
    Tables.txns,
  ];

  /// Nhật ký thông báo thô. Nặng và không phải dữ liệu sổ sách, nên chỉ chép
  /// khi user chủ động chọn.
  static const String rawLogsTable = Tables.rawLogs;

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  int get schemaVersion => AppDatabase.schemaVersion;

  Future<List<Map<String, Object?>>> dump(String table) async {
    final db = await _database;
    return db.query(table);
  }

  /// Xoá sạch các bảng, dùng cho kiểu nạp "thay thế toàn bộ".
  Future<void> clear(Iterable<String> names) async {
    final db = await _database;
    final batch = db.batch();
    for (final name in names) {
      batch.delete(name);
    }
    await batch.commit(noResult: true);
  }

  /// Nạp các dòng vào một bảng, bỏ qua dòng nào đụng ràng buộc trùng lặp.
  ///
  /// [keepIds] chỉ bật khi vừa xoá sạch bảng — giữ lại `id` cũ thì mọi tham
  /// chiếu trong file vẫn khớp. Lúc gộp thêm thì phải bỏ `id` đi, không thì
  /// dòng mới đè lên dòng đang có cùng số.
  ///
  /// Trả về số dòng thật sự được thêm.
  Future<int> insertAll(
    String table,
    List<Map<String, Object?>> rows, {
    required bool keepIds,
  }) async {
    if (rows.isEmpty) return 0;
    final db = await _database;
    var added = 0;
    await db.transaction((txn) async {
      for (final row in rows) {
        final values = Map<String, Object?>.from(row);
        if (!keepIds) values.remove('id');
        final id = await txn.insert(
          table,
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id != 0) added++;
      }
    });
    return added;
  }
}
