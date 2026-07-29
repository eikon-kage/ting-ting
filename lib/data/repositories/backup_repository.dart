import '../../core/date_range.dart';
import '../../domain/backup.dart';
import '../dao/backup_dao.dart';
import '../dao/txn_dao.dart';
import '../data_changes.dart';

/// Sao lưu và khôi phục toàn bộ dữ liệu.
///
/// Mọi thứ user tích luỹ nằm trong đúng một file SQLite trên máy: mất máy là
/// mất sạch, không có bản nào ở đâu khác. Lớp này là đường thoát duy nhất —
/// gói dữ liệu ra một file mang đi được, và nhận lại một file như thế.
class BackupRepository {
  BackupRepository(this._backup, this._txns, this._changes);

  final BackupDao _backup;
  final TxnDao _txns;
  final DataChanges _changes;

  /// Gói dữ liệu hiện tại thành một bản sao lưu.
  ///
  /// [includeRawLogs] kéo theo cả nhật ký thông báo thô: nặng hơn nhiều nhưng
  /// giữ lại được khả năng dựng lại giao dịch cho nguồn bật muộn.
  Future<BackupData> create({bool includeRawLogs = false}) async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in BackupDao.tables) {
      tables[table] = await _backup.dump(table);
    }
    if (includeRawLogs) {
      tables[BackupDao.rawLogsTable] = await _backup.dump(
        BackupDao.rawLogsTable,
      );
    }
    return BackupData(
      format: BackupData.currentFormat,
      schema: _backup.schemaVersion,
      createdAt: DateTime.now(),
      tables: tables,
    );
  }

  /// Đọc nội dung một file sao lưu. Ném [BackupError] khi file không dùng
  /// được — chỉ ở đây mới biết bản app này chịu được schema tới đời nào.
  BackupData parse(String raw) =>
      BackupData.decode(raw, supportedSchema: _backup.schemaVersion);

  /// Nạp một bản sao lưu vào máy.
  ///
  /// Kiểu [RestoreMode.merge] dựa vào chính các ràng buộc trùng lặp của
  /// database để lọc: giao dịch có khoá chống trùng, nhóm trùng tên, nguồn và
  /// mẫu bóc tách trùng tên package đều tự bị bỏ qua. Riêng quy tắc phân loại
  /// không có ràng buộc nào nên phải tự lọc ở đây.
  Future<RestoreReport> restore(
    BackupData data, {
    required RestoreMode mode,
  }) async {
    final replacing = mode == RestoreMode.replace;
    final incoming = data.tables.keys
        .where(_isKnownTable)
        .toList(growable: false);

    if (replacing) {
      // Chỉ xoá những bảng file này thật sự mang theo. Bản sao lưu không kèm
      // nhật ký thô mà lại xoá mất nhật ký đang có thì là phá thêm, không phải
      // khôi phục.
      await _backup.clear(incoming);
    }

    final added = <String, int>{};
    // Theo thứ tự chuẩn để bảng nào cũng được nạp sau thứ nó dựa vào.
    for (final table in [...BackupDao.tables, BackupDao.rawLogsTable]) {
      final rows = data.tables[table];
      if (rows == null) continue;
      final toInsert = replacing ? rows : await _withoutDuplicates(table, rows);
      added[table] = await _backup.insertAll(
        table,
        toInsert,
        keepIds: replacing,
      );
    }

    _changes.markChanged();
    return RestoreReport(mode: mode, added: added);
  }

  /// Bảng giao dịch dạng CSV. Không truyền [range] là xuất cả lịch sử.
  Future<String> exportCsv({DateRange? range}) async {
    final txns = range == null
        ? await _txns.search(limit: _csvRowLimit)
        : await _txns.inRange(range);
    return txnsToCsv(txns);
  }

  /// Bảng lạ trong file (do bản app khác tạo) bị bỏ qua thay vì làm hỏng cả
  /// lần nạp — nhưng cũng không được im lặng xoá bảng cùng tên trên máy.
  static bool _isKnownTable(String table) =>
      BackupDao.tables.contains(table) || table == BackupDao.rawLogsTable;

  /// Quy tắc phân loại không có ràng buộc trùng trong database, nên gộp hai
  /// lần cùng một file sẽ nhân đôi chúng. Lọc theo cặp từ khoá + nhóm.
  Future<List<Map<String, Object?>>> _withoutDuplicates(
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    if (table != _rulesTable) return rows;
    final existing = {
      for (final row in await _backup.dump(table)) _ruleKey(row),
    };
    return rows.where((row) => existing.add(_ruleKey(row))).toList();
  }

  static String _ruleKey(Map<String, Object?> row) =>
      '${row['keyword']}|${row['category']}';

  static const String _rulesTable = 'rules';

  /// Xuất "tất cả" vẫn phải có trần: máy dùng nhiều năm mà kéo hết bảng vào
  /// bộ nhớ một lượt thì app chết trước khi ghi được file.
  static const int _csvRowLimit = 100000;
}
