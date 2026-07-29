import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';

/// Tên bảng, để không rải chuỗi trần khắp các DAO.
class Tables {
  const Tables._();

  static const String txns = 'txns';
  static const String rawLogs = 'raw_logs';
  static const String sources = 'sources';
  static const String rules = 'rules';
  static const String parserProfiles = 'parser_profiles';
  static const String categories = 'categories';
  static const String settings = 'settings';
}

/// Câu lệnh tạo bảng dùng chung cho cả `onCreate` lẫn `onUpgrade`.
const String createParserProfilesTable =
    '''
  CREATE TABLE IF NOT EXISTS parser_profiles (
    package_name TEXT PRIMARY KEY,
    amount_label TEXT,
    amount_pattern TEXT,
    balance_label TEXT,
    balance_pattern TEXT,
    desc_label TEXT,
    desc_pattern TEXT,
    direction_mode TEXT NOT NULL DEFAULT 'auto',
    income_hints TEXT,
    expense_hints TEXT,
    only_if TEXT,
    ignore_if TEXT,
    sample_title TEXT,
    sample_content TEXT
  )
''';

const String createCategoriesTable =
    '''
  CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    keywords TEXT,
    built_in INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0
  )
''';

/// Lựa chọn lặt vặt của user (bật/tắt thông báo tổng kết, ...) dưới dạng
/// khoá–giá trị. Không đáng dựng mỗi thứ một cột, cũng không nên nằm ngoài
/// database — đã có sao lưu thì cài đặt cũng phải theo về máy mới.
const String createSettingsTable =
    '''
  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
''';

/// Đổ bộ nhóm dựng sẵn vào bảng rỗng.
///
/// Chỉ chạy khi bảng chưa có gì: user đã sửa danh sách của mình thì không ai
/// được nhét lại mấy nhóm mặc định vào.
Future<void> seedCategories(Database db) async {
  final existing =
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${Tables.categories}'),
      ) ??
      0;
  if (existing > 0) return;
  final batch = db.batch();
  for (final category in defaultCategories) {
    batch.insert(Tables.categories, category.toMap());
  }
  await batch.commit(noResult: true);
}

/// Mở và giữ kết nối SQLite. Chỉ lo phần hạ tầng — không có câu truy vấn
/// nghiệp vụ nào ở đây, chúng nằm trong `data/dao/`.
///
/// Toàn bộ dữ liệu nằm trên máy, không đẩy đi đâu.
class AppDatabase {
  AppDatabase();

  static final AppDatabase instance = AppDatabase();

  static const String _fileName = 'ting_ting.db';

  /// Đời schema hiện tại. Bản sao lưu ghi kèm con số này để lúc nạp còn biết
  /// file có mới hơn bản app đang chạy hay không.
  static const int schemaVersion = 4;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  /// v1 -> v2: thêm bảng mẫu bóc tách riêng cho từng ngân hàng.
  /// v2 -> v3: nhóm chi tiêu chuyển từ danh sách cứng trong code xuống bảng
  /// riêng để user tự thêm sửa xoá. Máy cũ được đổ đúng bộ nhóm cũ nên giao
  /// dịch đã lưu vẫn khớp tên nhóm.
  /// v3 -> v4: thêm bảng cài đặt khoá–giá trị.
  Future<void> _upgradeSchema(Database db, int from, int to) async {
    if (from < 2) await db.execute(createParserProfilesTable);
    if (from < 3) {
      await db.execute(createCategoriesTable);
      await seedCategories(db);
    }
    if (from < 4) await db.execute(createSettingsTable);
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${Tables.txns} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount INTEGER NOT NULL,
        balance INTEGER,
        description TEXT,
        category TEXT NOT NULL,
        raw_title TEXT,
        raw_content TEXT,
        post_time INTEGER NOT NULL,
        needs_review INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        excluded INTEGER NOT NULL DEFAULT 0,
        debt_type TEXT,
        person TEXT,
        account_kind TEXT NOT NULL DEFAULT 'bank',
        is_transfer INTEGER NOT NULL DEFAULT 0,
        fingerprint TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_txns_post_time ON ${Tables.txns} (post_time DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_txns_person ON ${Tables.txns} (person)',
    );
    await db.execute('''
      CREATE TABLE ${Tables.rawLogs} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        title TEXT,
        content TEXT,
        post_time INTEGER NOT NULL,
        parsed INTEGER NOT NULL DEFAULT 0,
        UNIQUE (package_name, title, content, post_time)
      )
    ''');
    await db.execute('''
      CREATE TABLE ${Tables.sources} (
        package_name TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE ${Tables.rules} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL,
        category TEXT NOT NULL,
        auto_exclude INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(createParserProfilesTable);
    await db.execute(createCategoriesTable);
    await db.execute(createSettingsTable);
    await seedCategories(db);
  }
}
