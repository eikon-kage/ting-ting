import 'package:sqflite/sqflite.dart';

import '../../core/date_range.dart';
import '../../models/models.dart';
import '../app_database.dart';

/// Mọi câu SQL của bảng giao dịch. Không nơi nào ngoài file này được viết SQL
/// cho bảng `txns`.
class TxnDao {
  TxnDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  // ------------------------------------------------------------------- ghi

  /// Trả về id của giao dịch vừa thêm, hoặc `0` nếu trùng với giao dịch đã có
  /// (Android hay bắn lại cùng một notification khi nó được cập nhật).
  Future<int> insert(Txn txn) async {
    final db = await _database;
    return db.insert(
      Tables.txns,
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> update(Txn txn) async {
    final db = await _database;
    await db.update(
      Tables.txns,
      txn.toMap(),
      where: 'id = ?',
      whereArgs: [txn.id],
    );
  }

  Future<void> deleteById(int id) async {
    final db = await _database;
    await db.delete(Tables.txns, where: 'id = ?', whereArgs: [id]);
  }

  /// Chuyển mọi giao dịch của một nhóm sang nhóm khác — dùng khi user đổi tên
  /// hoặc xoá nhóm. Trả về số giao dịch đã đổi.
  Future<int> replaceCategory(String from, String to) async {
    final db = await _database;
    return db.update(
      Tables.txns,
      {'category': to},
      where: 'category = ?',
      whereArgs: [from],
    );
  }

  // ------------------------------------------------------------------- đọc

  Future<Txn?> byId(int id) async {
    final db = await _database;
    final rows = await db.query(
      Tables.txns,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Txn.fromMap(rows.first);
  }

  Future<List<Txn>> inRange(DateRange range) async {
    final db = await _database;
    final rows = await db.query(
      Tables.txns,
      where: 'post_time >= ? AND post_time < ?',
      whereArgs: [range.fromMillis, range.toMillis],
      orderBy: 'post_time DESC',
    );
    return rows.map(Txn.fromMap).toList();
  }

  /// Tìm kiếm / lọc giao dịch. Mọi tham số đều tuỳ chọn.
  ///
  /// [minAmount] / [maxAmount] so trên số tiền tuyệt đối, không phân biệt thu
  /// hay chi — cột `amount` luôn dương, hướng tiền nằm ở cột `direction`.
  Future<List<Txn>> search({
    String? query,
    String? category,
    TxnDirection? direction,
    DateRange? range,
    int? minAmount,
    int? maxAmount,
    int limit = 500,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object>[];
    if (query != null && query.trim().isNotEmpty) {
      where.add('(description LIKE ? OR note LIKE ? OR raw_content LIKE ?)');
      final like = '%${query.trim()}%';
      args.addAll([like, like, like]);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    if (direction != null) {
      where.add('direction = ?');
      args.add(direction.code);
    }
    if (range != null) {
      where.add('post_time >= ? AND post_time < ?');
      args.addAll([range.fromMillis, range.toMillis]);
    }
    if (minAmount != null) {
      where.add('amount >= ?');
      args.add(minAmount);
    }
    if (maxAmount != null) {
      where.add('amount <= ?');
      args.add(maxAmount);
    }
    final rows = await db.query(
      Tables.txns,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'post_time DESC',
      limit: limit,
    );
    return rows.map(Txn.fromMap).toList();
  }

  /// Số giao dịch đang mang từng nhóm, tính trên toàn bộ lịch sử. Màn quản lý
  /// nhóm cần con số này để báo trước "xoá nhóm này thì bao nhiêu khoản đổi".
  Future<Map<String, int>> countsByCategory() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT category, COUNT(*) AS cnt FROM ${Tables.txns} GROUP BY category',
    );
    return {
      for (final row in rows)
        row['category'] as String: (row['cnt'] as int?) ?? 0,
    };
  }

  /// Các tháng đã có dữ liệu, mới nhất trước — dùng cho bộ chọn tháng.
  Future<List<DateTime>> monthsWithData() async {
    final db = await _database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT strftime('%Y-%m', post_time / 1000, 'unixepoch', 'localtime') AS ym "
      'FROM ${Tables.txns} ORDER BY ym DESC',
    );
    return rows.map((r) => _monthFromYm(r['ym'] as String)).toList();
  }

  // --------------------------------------------------------------- báo cáo

  /// Tổng chi theo từng nhóm trong khoảng thời gian, lớn nhất trước.
  /// Bỏ qua giao dịch đã đánh dấu "không tính".
  Future<List<CategoryTotal>> expenseByCategory(DateRange range) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT category, SUM(amount) AS total FROM ${Tables.txns} '
      "WHERE direction = 'out' AND $_countsInReport "
      'AND post_time >= ? AND post_time < ? '
      'GROUP BY category ORDER BY total DESC',
      [range.fromMillis, range.toMillis],
    );
    return rows
        .map(
          (r) => CategoryTotal(
            category: r['category'] as String,
            total: (r['total'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  /// Tổng thu / chi từng tháng, cũ đến mới, phục vụ biểu đồ cột.
  Future<List<MonthlyTotal>> monthlyTotals(DateRange range) async {
    final db = await _database;
    final rows = await db.rawQuery(
      "SELECT strftime('%Y-%m', post_time / 1000, 'unixepoch', 'localtime') AS ym, "
      "SUM(CASE WHEN direction = 'in' THEN amount ELSE 0 END) AS income, "
      "SUM(CASE WHEN direction = 'out' THEN amount ELSE 0 END) AS expense "
      'FROM ${Tables.txns} WHERE $_countsInReport '
      'AND post_time >= ? AND post_time < ? '
      'GROUP BY ym ORDER BY ym',
      [range.fromMillis, range.toMillis],
    );
    return rows
        .map(
          (r) => MonthlyTotal(
            month: _monthFromYm(r['ym'] as String),
            income: (r['income'] as int?) ?? 0,
            expense: (r['expense'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  /// Những nơi tiêu nhiều nhất, gom theo mô tả giao dịch.
  Future<List<SpendingSpot>> topSpending(DateRange range, {int limit = 5}) async {
    final db = await _database;
    final rows = await db.rawQuery(
      "SELECT COALESCE(NULLIF(description, ''), category) AS label, "
      'SUM(amount) AS total, COUNT(*) AS cnt FROM ${Tables.txns} '
      "WHERE direction = 'out' AND $_countsInReport "
      'AND post_time >= ? AND post_time < ? '
      'GROUP BY label ORDER BY total DESC LIMIT ?',
      [range.fromMillis, range.toMillis, limit],
    );
    return rows
        .map(
          (r) => SpendingSpot(
            label: r['label'] as String,
            total: (r['total'] as int?) ?? 0,
            count: (r['cnt'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  // ----------------------------------------------------------------- số dư

  /// Tiền mặt đang có, tính từ mọi giao dịch tiền mặt cộng với các lần rút /
  /// nộp tiền giữa hai ví. Không có nguồn nào báo con số này nên phải tự cộng.
  Future<int> cashBalance() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(CASE WHEN direction = 'in' THEN amount ELSE -amount END), 0)
         FROM ${Tables.txns} WHERE account_kind = 'cash') AS own,
        (SELECT COALESCE(SUM(CASE WHEN direction = 'out' THEN amount ELSE -amount END), 0)
         FROM ${Tables.txns} WHERE account_kind = 'bank' AND is_transfer = 1) AS moved
    ''');
    final row = rows.first;
    return ((row['own'] as int?) ?? 0) + ((row['moved'] as int?) ?? 0);
  }

  /// Số dư mới nhất của từng ngân hàng, lấy từ trường "SD:" trong thông báo.
  /// Ngân hàng nào không kèm số dư thì không xuất hiện ở đây.
  Future<List<BankBalance>> latestBankBalances() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT t.bank_name, t.balance, t.post_time FROM ${Tables.txns} t
      JOIN (
        SELECT bank_name, MAX(post_time) AS latest FROM ${Tables.txns}
        WHERE balance IS NOT NULL AND account_kind = 'bank'
        GROUP BY bank_name
      ) m ON m.bank_name = t.bank_name AND m.latest = t.post_time
      WHERE t.balance IS NOT NULL
      GROUP BY t.bank_name
      ORDER BY t.balance DESC
    ''');
    return rows
        .map(
          (r) => BankBalance(
            bankName: r['bank_name'] as String,
            balance: (r['balance'] as int?) ?? 0,
            at: DateTime.fromMillisecondsSinceEpoch(r['post_time'] as int),
          ),
        )
        .toList();
  }

  /// Mọi giao dịch của ví ngân hàng, cũ đến mới — nguyên liệu cho việc đối
  /// soát chuỗi số dư. Lấy cả khoản đã loại khỏi báo cáo lẫn khoản nợ: chúng
  /// không vào Thu–Chi nhưng tiền thì vẫn thật sự ra vào tài khoản, bỏ đi thì
  /// chuỗi số dư đứt.
  Future<List<Txn>> bankChain({DateRange? range}) async {
    final db = await _database;
    final rows = await db.query(
      Tables.txns,
      where: range == null
          ? "account_kind = 'bank'"
          : "account_kind = 'bank' AND post_time >= ? AND post_time < ?",
      whereArgs: range == null ? null : [range.fromMillis, range.toMillis],
      orderBy: 'post_time ASC, id ASC',
    );
    return rows.map(Txn.fromMap).toList();
  }

  // ------------------------------------------------------------------ nợ

  /// Số dư nợ theo từng người. Dương = người đó đang nợ mình,
  /// âm = mình đang nợ người đó. Tính trên toàn bộ lịch sử, không theo tháng.
  Future<List<DebtSummary>> debtBalances() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT person,
        SUM(CASE debt_type
              WHEN 'lend' THEN amount
              WHEN 'repay' THEN amount
              WHEN 'collect' THEN -amount
              WHEN 'borrow' THEN -amount
              ELSE 0 END) AS balance,
        COUNT(*) AS cnt
      FROM ${Tables.txns}
      WHERE debt_type IS NOT NULL AND person IS NOT NULL AND person != ''
      GROUP BY person ORDER BY ABS(balance) DESC
    ''');
    return rows
        .map(
          (r) => DebtSummary(
            person: r['person'] as String,
            balance: (r['balance'] as int?) ?? 0,
            count: (r['cnt'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  Future<List<Txn>> debtTxnsFor(String person) async {
    final db = await _database;
    final rows = await db.query(
      Tables.txns,
      where: 'debt_type IS NOT NULL AND person = ?',
      whereArgs: [person],
      orderBy: 'post_time DESC',
    );
    return rows.map(Txn.fromMap).toList();
  }

  /// Giao dịch đã đánh dấu là nợ nhưng chưa gán tên người.
  Future<List<Txn>> debtTxnsWithoutPerson() async {
    final db = await _database;
    final rows = await db.query(
      Tables.txns,
      where: "debt_type IS NOT NULL AND (person IS NULL OR person = '')",
      orderBy: 'post_time DESC',
    );
    return rows.map(Txn.fromMap).toList();
  }

  /// Tên người đã từng dùng, để gợi ý khi gán nợ.
  Future<List<String>> knownPeople() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT person, COUNT(*) AS cnt FROM ${Tables.txns} '
      "WHERE person IS NOT NULL AND person != '' "
      'GROUP BY person ORDER BY cnt DESC',
    );
    return rows.map((r) => r['person'] as String).toList();
  }

  /// Điều kiện chung của mọi báo cáo Thu–Chi: bỏ khoản đã loại, khoản nợ và
  /// tiền tự chuyển giữa hai ví của mình.
  static const String _countsInReport =
      'excluded = 0 AND debt_type IS NULL AND is_transfer = 0';

  /// "2026-07" -> DateTime(2026, 7)
  static DateTime _monthFromYm(String ym) {
    final parts = ym.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}
