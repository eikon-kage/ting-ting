import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/txn_factory.dart';
import 'package:ting_ting/models/models.dart';

Txn? adjust({
  required AccountKind kind,
  required int current,
  required int target,
  String wallet = 'Ví',
}) => TxnFactory.balanceAdjustment(
  accountKind: kind,
  walletName: wallet,
  current: current,
  target: target,
  at: DateTime(2026, 7, 28, 10),
);

void main() {
  group('Sửa số tiền đang có', () {
    test('số dư không đổi thì không ghi gì', () {
      expect(
        adjust(kind: AccountKind.cash, current: 500000, target: 500000),
        isNull,
      );
    });

    test('nhập số lớn hơn thì ghi một khoản tiền vào bằng đúng phần thiếu', () {
      final txn = adjust(
        kind: AccountKind.cash,
        current: 500000,
        target: 800000,
      )!;
      expect(txn.direction, TxnDirection.income);
      expect(txn.amount, 300000);
    });

    test('nhập số nhỏ hơn thì ghi một khoản tiền ra bằng đúng phần dư', () {
      final txn = adjust(
        kind: AccountKind.cash,
        current: 800000,
        target: 500000,
      )!;
      expect(txn.direction, TxnDirection.expense);
      expect(txn.amount, 300000);
    });

    test('kéo được số dư âm về 0', () {
      final txn = adjust(kind: AccountKind.cash, current: -120000, target: 0)!;
      expect(txn.direction, TxnDirection.income);
      expect(txn.amount, 120000);
    });

    test('không tính vào Thu–Chi của tháng', () {
      final txn = adjust(
        kind: AccountKind.cash,
        current: 0,
        target: 1000000,
      )!;
      expect(txn.excluded, isTrue);
      expect(txn.countsInReport, isFalse);
      expect(TxnTotals.of([txn]).net, 0);
    });

    test('ví ngân hàng ghi luôn số dư mới, tiền mặt thì không', () {
      final bank = adjust(
        kind: AccountKind.bank,
        current: 1000000,
        target: 900000,
        wallet: 'Vietcombank',
      )!;
      expect(bank.balance, 900000);
      expect(bank.bankName, 'Vietcombank');

      final cash = adjust(kind: AccountKind.cash, current: 0, target: 900000)!;
      expect(cash.balance, isNull);
    });

    test('không khai tên ví thì lấy tên ví mặc định', () {
      final txn = adjust(
        kind: AccountKind.cash,
        current: 0,
        target: 50000,
        wallet: '  ',
      )!;
      expect(txn.bankName, AccountKind.cash.label);
    });

    test('là giao dịch nhập tay, không phải khoản nợ hay chuyển ví', () {
      final txn = adjust(kind: AccountKind.cash, current: 0, target: 50000)!;
      expect(txn.isManual, isTrue);
      expect(txn.isDebt, isFalse);
      expect(txn.isTransfer, isFalse);
    });

    test('hai lần sửa liên tiếp không bị coi là trùng nhau', () {
      final first = adjust(kind: AccountKind.cash, current: 0, target: 50000)!;
      final second = adjust(kind: AccountKind.cash, current: 0, target: 50000)!;
      expect(first.fingerprint, isNot(second.fingerprint));
    });
  });
}
