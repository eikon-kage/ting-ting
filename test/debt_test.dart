import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/models/txn.dart';

Txn debtTxn(DebtType type, int amount) => Txn(
  packageName: Txn.manualPackage,
  bankName: 'Tiền mặt',
  accountKind: AccountKind.cash,
  direction: type.direction,
  amount: amount,
  category: 'Khác',
  rawTitle: '',
  rawContent: '',
  postTime: DateTime(2026, 7, 28),
  debtType: type,
  person: 'Nam',
);

void main() {
  group('DebtType.direction', () {
    test('cho vay và trả nợ là tiền ra', () {
      expect(DebtType.lend.direction, TxnDirection.expense);
      expect(DebtType.repay.direction, TxnDirection.expense);
    });

    test('đi vay và thu nợ là tiền vào', () {
      expect(DebtType.borrow.direction, TxnDirection.income);
      expect(DebtType.collect.direction, TxnDirection.income);
    });
  });

  group('Khoản nợ ghi tay', () {
    test('không được tính vào báo cáo Thu–Chi', () {
      for (final type in DebtType.values) {
        expect(debtTxn(type, 100000).countsInReport, isFalse);
      }
    });

    test('cho vay làm người kia nợ mình thêm, thu nợ thì giảm đi', () {
      expect(debtTxn(DebtType.lend, 500000).debtEffect, 500000);
      expect(debtTxn(DebtType.collect, 200000).debtEffect, -200000);
    });

    test('đi vay làm mình nợ họ, trả nợ thì giảm đi', () {
      expect(debtTxn(DebtType.borrow, 500000).debtEffect, -500000);
      expect(debtTxn(DebtType.repay, 200000).debtEffect, 200000);
    });

    test('vay rồi trả hết thì số dư nợ về 0', () {
      final txns = [
        debtTxn(DebtType.lend, 1000000),
        debtTxn(DebtType.collect, 400000),
        debtTxn(DebtType.collect, 600000),
      ];
      expect(txns.fold(0, (sum, t) => sum + t.debtEffect), 0);
    });

    test('đã gán tên người thì không còn cờ needsPerson', () {
      final txn = debtTxn(DebtType.lend, 100000);
      expect(txn.isDebt, isTrue);
      expect(txn.needsPerson, isFalse);
    });
  });
}
