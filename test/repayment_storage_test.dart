import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ting_ting/data/data_store.dart';
import 'package:ting_ting/domain/repayment_match.dart';
import 'package:ting_ting/models/models.dart';

/// Confirming a repayment writes to two places at once: the transaction, and
/// the debt book or bill it pays off. These run against a real database so a
/// half-written confirmation would show up.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final data = DataStore.instance;
  var minute = 0;
  final created = <int>[];

  Future<Txn> record(Txn txn) async {
    final saved = (await data.txns.add(txn))!;
    created.add(saved.id!);
    return saved;
  }

  /// A distinct minute per transaction keeps the duplicate guard out of it.
  Txn bankTxn(TxnDirection direction, int amount, String content) => Txn(
    packageName: 'com.vietcombank',
    bankName: 'Vietcombank',
    direction: direction,
    amount: amount,
    description: content,
    category: direction == TxnDirection.income ? Category.income : 'Khác',
    rawTitle: 'Biến động số dư',
    rawContent: content,
    postTime: DateTime(2026, 10, 2).add(Duration(minutes: minute++)),
  );

  tearDown(() async {
    for (final id in created) {
      await data.txns.remove(id);
    }
    created.clear();
    for (final entry in await data.bills.overview()) {
      await data.bills.remove(entry.bill.key);
    }
  });

  test(
    'confirming a debt repayment moves the money into the debt book',
    () async {
      final lent = await record(
        bankTxn(TxnDirection.expense, 500000, 'chuyen tien TRAN VAN QUYET'),
      );
      await data.debts.assign(lent, type: DebtType.lend, person: 'Quyết');
      final back = await record(
        bankTxn(TxnDirection.income, 500000, 'TRAN VAN QUYET tra tien'),
      );

      final match = await data.repayments.matchFor(back);
      expect(match, isA<DebtRepaymentMatch>());
      expect(await data.repayments.confirm(back, match!), isTrue);

      final saved = await data.txns.byId(back.id!);
      expect(saved?.debtType, DebtType.collect);
      expect(saved?.person, 'Quyết');
      final overview = await data.debts.overview();
      expect(overview.people.firstWhere((p) => p.person == 'Quyết').balance, 0);
      // Settled now, so asking again finds nothing.
      expect(await data.repayments.matchFor(saved!), isNull);
    },
  );

  test('confirming a bill payback marks the share and the category', () async {
    final bill = Bill.create(title: 'Ăn lẩu', others: const ['Tùng', 'Thư']);
    await data.bills.save(bill);
    await data.bills.saveItem(
      BillItem.create(
        billKey: bill.key,
        label: 'Lẩu',
        amount: 900000,
        payer: Bill.me,
        mode: BillSplitMode.equal,
        shares: const [],
      ),
    );
    final fromTung = await record(
      bankTxn(TxnDirection.income, 300000, 'NGUYEN THANH TUNG tien lau'),
    );

    final match = await data.repayments.matchFor(fromTung);
    expect(match, isA<BillRepaymentMatch>());
    expect(await data.repayments.confirm(fromTung, match!), isTrue);

    expect((await data.txns.byId(fromTung.id!))?.category, Category.shareBill);
    final afterTung = await data.bills.byKey(bill.key);
    expect(afterTung?.repaid, {'Tùng': 300000});
    expect(afterTung?.settled, isFalse);

    final fromThu = await record(
      bankTxn(TxnDirection.income, 300000, 'LE ANH THU tien lau'),
    );
    final thuMatch = await data.repayments.matchFor(fromThu);
    expect(await data.repayments.confirm(fromThu, thuMatch!), isTrue);

    // The last share in closes the bill.
    final done = await data.bills.byKey(bill.key);
    expect(done?.repaid, {'Tùng': 300000, 'Thư': 300000});
    expect(done?.settled, isTrue);
  });

  test('a stale confirmation writes nothing', () async {
    final lent = await record(
      bankTxn(TxnDirection.expense, 500000, 'chuyen tien TRAN VAN QUYET'),
    );
    await data.debts.assign(lent, type: DebtType.lend, person: 'Quyết');
    final back = await record(
      bankTxn(TxnDirection.income, 500000, 'TRAN VAN QUYET tra tien'),
    );
    final match = (await data.repayments.matchFor(back))!;

    // The debt is cleared some other way before the user taps the button.
    await data.debts.release(lent);

    expect(await data.repayments.confirm(back, match), isFalse);
    expect((await data.txns.byId(back.id!))?.isDebt, isFalse);
  });
}
