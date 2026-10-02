import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/categorizer.dart';
import 'package:ting_ting/models/models.dart';

/// Money flowing in is not all the same thing. Salary is earned; a friend
/// paying back their half of dinner is a refund on money already spent; money
/// borrowed has to go back out again. All three raise the balance, so the "Thu"
/// total holds all three — but the spending figure only means something once
/// the share-bill refunds are taken out of it.

Txn income(int amount, {required String category}) => Txn(
  packageName: 'com.vcb',
  bankName: 'VCB',
  direction: TxnDirection.income,
  amount: amount,
  category: category,
  rawTitle: '',
  rawContent: '',
  postTime: DateTime(2026, 8, 18, 9, 30),
);

Txn expense(int amount, {String category = 'Ăn uống'}) => Txn(
  packageName: 'com.vcb',
  bankName: 'VCB',
  direction: TxnDirection.expense,
  amount: amount,
  category: category,
  rawTitle: '',
  rawContent: '',
  postTime: DateTime(2026, 8, 18, 12, 0),
);

void main() {
  group('IncomeKind của một giao dịch', () {
    test('nhóm quyết định kiểu tiền vào', () {
      expect(
        income(1000, category: Category.income).incomeKind,
        IncomeKind.earned,
      );
      expect(
        income(1000, category: Category.shareBill).incomeKind,
        IncomeKind.shareBill,
      );
      expect(
        income(1000, category: Category.borrowed).incomeKind,
        IncomeKind.borrowed,
      );
    });

    test('nhóm user tự đặt cho khoản thu là tiền kiếm được', () {
      expect(
        income(1000, category: 'Tiền cho thuê').incomeKind,
        IncomeKind.earned,
      );
    });

    test('khoản chi không có kiểu tiền vào', () {
      expect(expense(1000, category: Category.shareBill).incomeKind, isNull);
    });
  });

  group('TxnTotals tách ba kiểu tiền vào', () {
    final totals = TxnTotals.of([
      income(18000000, category: Category.income),
      income(700000, category: Category.shareBill),
      income(500000, category: Category.borrowed),
      expense(1000000),
    ]);

    test('Thu vẫn là trọn cả ba kiểu', () {
      expect(totals.income, 19200000);
    });

    test('từng kiểu được đếm riêng', () {
      expect(totals.shareBill, 700000);
      expect(totals.borrowed, 500000);
      expect(totals.earned, 18000000);
    });

    test('số đã chi trừ phần người ta trả lại tiền bill', () {
      expect(totals.expense, 1000000);
      expect(totals.netExpense, 300000);
    });

    test('còn lại vẫn là tiền thật đổi trong kỳ', () {
      expect(totals.net, 18200000);
    });

    test('tiền vay không được trừ vào số đã chi', () {
      // Vay 500 nghìn rồi tiêu 1 triệu thì vẫn là tiêu 1 triệu — khoản vay chỉ
      // làm ví dày lên, không bù cho khoản nào đã chi.
      final borrowed = TxnTotals.of([
        income(500000, category: Category.borrowed),
        expense(1000000),
      ]);
      expect(borrowed.netExpense, 1000000);
    });

    test('trả lại nhiều hơn đã chi trong kỳ thì đã chi về 0, không âm', () {
      // Bữa ăn tính vào tháng trước, tiền bạn bè trả lại về tháng này.
      final refundOnly = TxnTotals.of([
        income(700000, category: Category.shareBill),
        expense(200000),
      ]);
      expect(refundOnly.netExpense, 0);
    });

    test('khoản nợ và khoản chuyển ví không lọt vào kiểu nào', () {
      final skipped = TxnTotals.of([
        income(300000, category: Category.shareBill).copyWith(
          debtType: DebtType.borrow,
          person: 'Nam',
        ),
        income(400000, category: Category.shareBill).copyWith(excluded: true),
        income(500000, category: Category.borrowed).copyWith(isTransfer: true),
      ]);
      expect(skipped.income, 0);
      expect(skipped.shareBill, 0);
      expect(skipped.borrowed, 0);
    });

    test('không có giao dịch nào thì mọi con số bằng 0', () {
      expect(TxnTotals.zero.shareBill, 0);
      expect(TxnTotals.zero.borrowed, 0);
      expect(TxnTotals.zero.earned, 0);
      expect(TxnTotals.zero.netExpense, 0);
    });
  });

  group('Đoán nhóm cho tiền vào', () {
    String guess(String text) =>
        Categorizer.categorize(text, TxnDirection.income).category;

    test('nội dung nhắc tới chia bill thì vào nhóm Chia bill', () {
      expect(guess('Nam chuyen tien bill di Da Lat'), Category.shareBill);
      expect(guess('gop tien an toi'), Category.shareBill);
    });

    test('nội dung nhắc tới vay thì vào nhóm Tiền vay', () {
      expect(guess('Cho muon tien dong hoc phi'), Category.borrowed);
      expect(guess('vay tien Lan'), Category.borrowed);
    });

    test('không nhắc gì thì về nhóm Lương', () {
      expect(guess('CT TNHH ABC thanh toan'), Category.income);
    });

    test('từ khoá của nhóm chi không kéo được khoản thu sang', () {
      // "highlands" là từ khoá của Ăn uống — một khoản tiền vào có chữ đó vẫn
      // là tiền vào, không phải một lần đi cà phê.
      expect(guess('Hoan tien HIGHLANDS COFFEE'), Category.income);
    });
  });
}
