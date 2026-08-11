import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../app_database.dart';

/// SQL của hai bảng chia bill.
class BillDao {
  BillDao(this._db);

  final AppDatabase _db;

  Future<Database> get _database => _db.database;

  /// Bill mới nhất lên đầu.
  Future<List<Bill>> allBills() async {
    final db = await _database;
    final rows = await db.query(Tables.bills, orderBy: 'created_at DESC');
    return rows.map(Bill.fromMap).toList();
  }

  Future<Bill?> billByKey(String key) async {
    final db = await _database;
    final rows = await db.query(
      Tables.bills,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : Bill.fromMap(rows.first);
  }

  Future<List<BillItem>> itemsOf(String billKey) async {
    final db = await _database;
    final rows = await db.query(
      Tables.billItems,
      where: 'bill_key = ?',
      whereArgs: [billKey],
      orderBy: 'created_at',
    );
    return rows.map(BillItem.fromMap).toList();
  }

  /// Mục của mọi bill, gom theo bill — màn danh sách cần tổng của từng bill
  /// nên lấy một lượt còn hơn mỗi dòng một truy vấn.
  Future<Map<String, List<BillItem>>> itemsByBill() async {
    final db = await _database;
    final rows = await db.query(Tables.billItems, orderBy: 'created_at');
    final result = <String, List<BillItem>>{};
    for (final row in rows) {
      final item = BillItem.fromMap(row);
      (result[item.billKey] ??= []).add(item);
    }
    return result;
  }

  Future<void> saveBill(Bill bill) async {
    final db = await _database;
    await db.insert(
      Tables.bills,
      bill.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Xoá bill kéo theo mọi mục của nó — không có ràng buộc khoá ngoại nào lo
  /// việc đó hộ, để lại thì chúng thành mục mồ côi không màn nào hiện ra.
  Future<void> deleteBill(String key) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete(Tables.billItems, where: 'bill_key = ?', whereArgs: [key]);
    batch.delete(Tables.bills, where: 'key = ?', whereArgs: [key]);
    await batch.commit(noResult: true);
  }

  Future<void> saveItem(BillItem item) async {
    final db = await _database;
    await db.insert(
      Tables.billItems,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteItem(String key) async {
    final db = await _database;
    await db.delete(Tables.billItems, where: 'key = ?', whereArgs: [key]);
  }
}
