import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ting_ting/data/data_store.dart';
import 'package:ting_ting/models/models.dart';

/// Bill được lưu bằng khoá chuỗi chứ không phải id tự tăng, và phần chia của
/// từng người nằm gọn trong một cột văn bản. Test chạy qua database thật để
/// chắc rằng ghi xuống rồi đọc lên vẫn ra đúng con số ấy.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final data = DataStore.instance;

  Future<Bill> newBill(String title) async {
    final bill = Bill.create(title: title, others: const ['Nam', 'Lan']);
    await data.bills.save(bill);
    return bill;
  }

  tearDown(() async {
    for (final entry in await data.bills.overview()) {
      await data.bills.remove(entry.bill.key);
    }
  });

  test('bill ghi xuống rồi đọc lên vẫn đủ thành viên', () async {
    final bill = await newBill('Đi Đà Lạt');
    final saved = await data.bills.byKey(bill.key);

    expect(saved?.title, 'Đi Đà Lạt');
    expect(saved?.members, [Bill.me, 'Nam', 'Lan']);
    expect(saved?.settled, isFalse);
  });

  test('các khoản của bill giữ nguyên cách chia', () async {
    final bill = await newBill('Ăn lẩu');
    await data.bills.saveItem(
      BillItem.create(
        billKey: bill.key,
        label: 'Lẩu',
        amount: 900000,
        payer: Bill.me,
        mode: BillSplitMode.equal,
        shares: const [BillShare(Bill.me), BillShare('Nam'), BillShare('Lan')],
      ),
    );
    await data.bills.saveItem(
      BillItem.create(
        billKey: bill.key,
        label: 'Bia',
        amount: 300000,
        payer: 'Nam',
        mode: BillSplitMode.custom,
        shares: const [BillShare(Bill.me, 100000), BillShare('Nam', 200000)],
      ),
    );

    final items = await data.bills.items(bill.key);
    expect(items.length, 2);
    expect(items.first.label, 'Lẩu');
    expect(items.first.people, [Bill.me, 'Nam', 'Lan']);
    expect(items.last.mode, BillSplitMode.custom);
    expect(items.last.assigned, 300000);
  });

  test('màn danh sách nhận luôn số đã chốt của từng bill', () async {
    final bill = await newBill('Cà phê');
    await data.bills.saveItem(
      BillItem.create(
        billKey: bill.key,
        label: 'Cà phê',
        amount: 300000,
        payer: Bill.me,
        mode: BillSplitMode.equal,
        shares: const [],
      ),
    );

    final entry = (await data.bills.overview()).single;
    expect(entry.settlement.total, 300000);
    // Trả hộ 300k, phần mình 100k, còn được nhận 200k từ hai người kia.
    expect(entry.settlement.myShare, 100000);
    expect(entry.settlement.transfers.length, 2);
  });

  test('sửa một khoản thì đè lên chính nó, không thành hai dòng', () async {
    final bill = await newBill('Xăng xe');
    final item = BillItem.create(
      billKey: bill.key,
      label: 'Xăng',
      amount: 100000,
      payer: Bill.me,
      mode: BillSplitMode.equal,
      shares: const [],
    );
    await data.bills.saveItem(item);
    await data.bills.saveItem(item.copyWith(amount: 150000));

    final items = await data.bills.items(bill.key);
    expect(items.length, 1);
    expect(items.single.amount, 150000);
  });

  test('xoá bill kéo theo mọi khoản của nó', () async {
    final bill = await newBill('Đi biển');
    await data.bills.saveItem(
      BillItem.create(
        billKey: bill.key,
        label: 'Phòng',
        amount: 2000000,
        payer: 'Lan',
        mode: BillSplitMode.equal,
        shares: const [],
      ),
    );

    await data.bills.remove(bill.key);

    expect(await data.bills.byKey(bill.key), isNull);
    expect(await data.bills.items(bill.key), isEmpty);
  });
}
