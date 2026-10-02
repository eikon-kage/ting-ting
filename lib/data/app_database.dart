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
  static const String bills = 'bills';
  static const String billItems = 'bill_items';
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

/// Bill chia tiền và các mục của nó.
///
/// Khoá chính là chuỗi `key` chứ không phải số tự tăng: bản sao lưu kiểu "gộp
/// thêm" bỏ `id` đi để khỏi đè lên dòng đang có, mà mục thì phải bám được vào
/// đúng bill của nó sau khi nạp. Khoá chuỗi đi theo dòng nên mối nối không đứt,
/// và nạp lại cùng một file nhiều lần cũng không sinh bản sao.
const String createBillsTable =
    '''
  CREATE TABLE IF NOT EXISTS bills (
    key TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    members TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    settled INTEGER NOT NULL DEFAULT 0,
    repaid TEXT
  )
''';

/// Schema version that added `bills.repaid`, what each member has already
/// paid back to the owner of the phone.
const int billRepaidSchema = 7;

const String createBillItemsTable =
    '''
  CREATE TABLE IF NOT EXISTS bill_items (
    key TEXT PRIMARY KEY,
    bill_key TEXT NOT NULL,
    label TEXT NOT NULL,
    amount INTEGER NOT NULL,
    payer TEXT NOT NULL,
    split_mode TEXT NOT NULL DEFAULT 'equal',
    shares TEXT,
    created_at INTEGER NOT NULL
  )
''';

const String createBillItemsIndex =
    'CREATE INDEX IF NOT EXISTS idx_bill_items_bill '
    'ON bill_items (bill_key)';

/// Tên nhóm tiền vào trước khi tiền vào được tách làm ba kiểu.
const String legacyIncomeCategory = 'Thu nhập';

/// Đời schema mà [splitIncomeCategories] dựng nên. Bản sao lưu cũ hơn con số
/// này còn mang tên nhóm cũ nên nạp xong phải chạy lại phép tách ấy.
const int incomeCategorySchema = 6;

/// Tách tiền vào làm ba nhóm hệ thống trên máy đã có dữ liệu.
///
/// Nhóm "Thu nhập" cũ đổi tên thành "Lương": nó vẫn giữ đúng vai trò ấy — chỗ
/// mọi khoản tiền vào rơi vào khi chưa ai nói nó thuộc kiểu nào — nên đổi tên
/// đúng hơn là dựng nhóm mới rồi bỏ nhóm cũ nằm đấy. Giao dịch và quy tắc đang
/// mang tên cũ phải được kéo theo, nếu không cả một mảng thu nhập cũ rớt khỏi
/// nhóm của nó.
Future<void> splitIncomeCategories(Database db) async {
  final taken =
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM ${Tables.categories} WHERE name = ?',
          [Category.income],
        ),
      ) ??
      0;
  if (taken > 0) {
    // User đã tự tạo một nhóm trùng đúng tên mới. Cột `name` là UNIQUE nên
    // không đổi tên được — gộp về nhóm của user thay vì để hai nhóm cùng tên.
    await db.delete(
      Tables.categories,
      where: 'name = ?',
      whereArgs: [legacyIncomeCategory],
    );
  } else {
    await db.update(
      Tables.categories,
      {'name': Category.income},
      where: 'name = ?',
      whereArgs: [legacyIncomeCategory],
    );
  }
  for (final table in [Tables.txns, Tables.rules]) {
    await db.update(
      table,
      {'category': Category.income},
      where: 'category = ?',
      whereArgs: [legacyIncomeCategory],
    );
  }

  // Hai nhóm còn lại xếp ngay sau nhóm lương: danh sách sắp theo `sort_order`
  // rồi tới `id`, nên cùng số thứ tự là chúng đứng liền sau.
  final order =
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT sort_order FROM ${Tables.categories} WHERE name = ?',
          [Category.income],
        ),
      ) ??
      0;
  for (final category in defaultCategories) {
    if (!Category.incomeNames.contains(category.name)) continue;
    final exists =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${Tables.categories} WHERE name = ?',
            [category.name],
          ),
        ) ??
        0;
    if (exists == 0) {
      await db.insert(
        Tables.categories,
        category.copyWith(sortOrder: order).toMap(),
      );
      continue;
    }
    // Nhóm đã có sẵn — của user hay là nhóm lương vừa đổi tên. Phần mềm tự
    // nhắc tới ba tên này nên chúng phải là nhóm hệ thống, không cho xoá.
    await db.update(
      Tables.categories,
      {'built_in': 1},
      where: 'name = ?',
      whereArgs: [category.name],
    );
  }
}

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
  static const int schemaVersion = billRepaidSchema;

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
  /// v4 -> v5: thêm hai bảng chia bill.
  /// v5 -> v6: tiền vào tách làm ba nhóm — Lương, Chia bill, Tiền vay.
  /// v6 -> v7: bills remember who has already paid their share back.
  Future<void> _upgradeSchema(Database db, int from, int to) async {
    if (from < 2) await db.execute(createParserProfilesTable);
    if (from < 3) {
      await db.execute(createCategoriesTable);
      await seedCategories(db);
    }
    if (from < 4) await db.execute(createSettingsTable);
    if (from < 5) {
      await db.execute(createBillsTable);
      await db.execute(createBillItemsTable);
      await db.execute(createBillItemsIndex);
    }
    if (from < incomeCategorySchema) await splitIncomeCategories(db);
    // Below v5 the table was just created above with the column already in it.
    if (from >= 5 && from < billRepaidSchema) {
      await db.execute('ALTER TABLE ${Tables.bills} ADD COLUMN repaid TEXT');
    }
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
    await db.execute(createBillsTable);
    await db.execute(createBillItemsTable);
    await db.execute(createBillItemsIndex);
    await seedCategories(db);
  }
}
