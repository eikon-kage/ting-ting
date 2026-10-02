import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ting_ting/data/app_database.dart';
import 'package:ting_ting/models/models.dart';

/// Splitting money-in into three categories renames the old "Thu nhập" instead
/// of dropping it, so the upgrade has to carry every transaction and rule that
/// still names the old category. Miss that and a phone that has been collecting
/// notifications for months loses its whole income history from the reports.

/// A v5 database: the old category list, plus the two tables that copy category
/// names into their own rows.
Future<Database> legacyDatabase({List<String> extraCategories = const []}) async {
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await db.execute(createCategoriesTable);
  await db.execute(
    'CREATE TABLE ${Tables.txns} (id INTEGER PRIMARY KEY, category TEXT)',
  );
  await db.execute(
    'CREATE TABLE ${Tables.rules} '
    '(id INTEGER PRIMARY KEY, keyword TEXT, category TEXT)',
  );
  await db.insert(Tables.categories, {
    'name': legacyIncomeCategory,
    'keywords': '',
    'built_in': 1,
    'sort_order': 0,
  });
  await db.insert(Tables.categories, {
    'name': 'Ăn uống',
    'keywords': 'an uong',
    'built_in': 0,
    'sort_order': 1,
  });
  for (final (index, name) in extraCategories.indexed) {
    await db.insert(Tables.categories, {
      'name': name,
      'keywords': '',
      'built_in': 0,
      'sort_order': 20 + index,
    });
  }
  return db;
}

Future<List<String>> categoryNames(Database db) async {
  final rows = await db.query(Tables.categories, orderBy: 'sort_order, id');
  return [for (final row in rows) row['name'] as String];
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('nhóm "Thu nhập" cũ thành nhóm "Lương"', () async {
    final db = await legacyDatabase();
    await splitIncomeCategories(db);

    final names = await categoryNames(db);
    expect(names, isNot(contains(legacyIncomeCategory)));
    expect(names, contains(Category.income));
    await db.close();
  });

  test('hai nhóm tiền vào mới xếp ngay sau nhóm lương', () async {
    final db = await legacyDatabase();
    await splitIncomeCategories(db);

    expect(await categoryNames(db), [
      Category.income,
      Category.shareBill,
      Category.borrowed,
      'Ăn uống',
    ]);
    await db.close();
  });

  test('ba nhóm tiền vào đều là nhóm hệ thống, không xoá được', () async {
    final db = await legacyDatabase();
    await splitIncomeCategories(db);

    for (final name in Category.incomeNames) {
      final rows = await db.query(
        Tables.categories,
        where: 'name = ?',
        whereArgs: [name],
      );
      expect(Category.fromMap(rows.single).builtIn, isTrue, reason: name);
    }
    await db.close();
  });

  test('giao dịch và quy tắc mang tên nhóm cũ được kéo theo', () async {
    final db = await legacyDatabase();
    await db.insert(Tables.txns, {'category': legacyIncomeCategory});
    await db.insert(Tables.txns, {'category': 'Ăn uống'});
    await db.insert(Tables.rules, {
      'keyword': 'tra luong',
      'category': legacyIncomeCategory,
    });

    await splitIncomeCategories(db);

    final txns = await db.query(Tables.txns, orderBy: 'id');
    expect(txns.map((row) => row['category']), [Category.income, 'Ăn uống']);
    final rules = await db.query(Tables.rules);
    expect(rules.single['category'], Category.income);
    await db.close();
  });

  test('user đã tự tạo nhóm trùng tên thì gộp về nhóm đó', () async {
    // Cột `name` là UNIQUE nên không đổi tên chồng lên được — giao dịch phải
    // về nhóm của user, và không được còn lại hai nhóm cùng tên.
    final db = await legacyDatabase(extraCategories: [Category.income]);
    await db.insert(Tables.txns, {'category': legacyIncomeCategory});

    await splitIncomeCategories(db);

    final names = await categoryNames(db);
    expect(names.where((name) => name == Category.income), hasLength(1));
    expect(names, isNot(contains(legacyIncomeCategory)));
    final txns = await db.query(Tables.txns);
    expect(txns.single['category'], Category.income);
    await db.close();
  });

  test('chạy lại lần nữa không sinh thêm nhóm', () async {
    final db = await legacyDatabase();
    await splitIncomeCategories(db);
    final once = await categoryNames(db);
    await splitIncomeCategories(db);

    expect(await categoryNames(db), once);
    await db.close();
  });
}
