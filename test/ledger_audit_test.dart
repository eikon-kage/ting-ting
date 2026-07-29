import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/ledger_audit.dart';
import 'package:ting_ting/models/models.dart';

var _nextId = 1;

/// Một giao dịch ngân hàng rút gọn: chỉ khai những thứ chuỗi số dư quan tâm.
Txn bank({
  required int amount,
  required bool income,
  int? balance,
  String name = 'VCB',
  int minute = 0,
  bool excluded = false,
  DebtType? debtType,
  bool isTransfer = false,
}) => Txn(
  id: _nextId++,
  packageName: 'com.vcb',
  bankName: name,
  direction: income ? TxnDirection.income : TxnDirection.expense,
  amount: amount,
  balance: balance,
  category: 'Khác',
  rawTitle: '',
  rawContent: '',
  postTime: DateTime(2026, 7, 20, 8, minute),
  excluded: excluded,
  debtType: debtType,
  person: debtType == null ? null : 'Bố',
  isTransfer: isTransfer,
);

Txn cash({required int amount, required bool income, int minute = 0}) => Txn(
  id: _nextId++,
  packageName: Txn.manualPackage,
  bankName: 'Tiền mặt',
  direction: income ? TxnDirection.income : TxnDirection.expense,
  amount: amount,
  category: 'Khác',
  rawTitle: '',
  rawContent: '',
  postTime: DateTime(2026, 7, 20, 8, minute),
  accountKind: AccountKind.cash,
);

void main() {
  setUp(() => _nextId = 1);

  group('Đối soát chuỗi số dư', () {
    test('chuỗi khớp thì không báo chỗ hở nào', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 900000, minute: 1),
        bank(amount: 50000, income: false, balance: 850000, minute: 2),
        bank(amount: 200000, income: true, balance: 1050000, minute: 3),
      ]);

      expect(audit.isClean, isTrue);
      expect(audit.gapCount, 0);
      expect(audit.checked, 3);
    });

    test('số dư tụt nhiều hơn khoản đã ghi -> thiếu một khoản chi', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 900000, minute: 1),
        // Sổ tính ra 850.000 nhưng ngân hàng báo 820.000: hụt 30.000.
        bank(amount: 50000, income: false, balance: 820000, minute: 2),
      ]);

      expect(audit.gapCount, 1);
      final gap = audit.gaps.single;
      expect(gap.direction, TxnDirection.expense);
      expect(gap.amount, 30000);
      expect(gap.expected, 850000);
      expect(gap.actual, 820000);
      expect(gap.bankName, 'VCB');
    });

    test('số dư cao hơn dự tính -> thiếu một khoản thu', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 900000, minute: 1),
        bank(amount: 100000, income: false, balance: 1300000, minute: 2),
      ]);

      final gap = audit.gaps.single;
      expect(gap.direction, TxnDirection.income);
      expect(gap.amount, 500000);
    });

    test('chỗ hở chỉ ra đúng khoảng thời gian giữa hai mốc', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 900000, minute: 5),
        bank(amount: 100000, income: false, balance: 700000, minute: 40),
      ]);

      final gap = audit.gaps.single;
      expect(gap.from, DateTime(2026, 7, 20, 8, 5));
      expect(gap.to, DateTime(2026, 7, 20, 8, 40));
    });

    test('giao dịch không kèm số dư vẫn được cộng vào, không báo lệch oan', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 900000, minute: 1),
        // Ngân hàng không nói số dư sau khoản này, nhưng nó đã được ghi đúng.
        bank(amount: 200000, income: false, minute: 2),
        bank(amount: 100000, income: false, balance: 600000, minute: 3),
      ]);

      expect(audit.isClean, isTrue);
    });

    test('khoản nợ và khoản đã loại vẫn làm đổi số dư nên phải tính', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 900000, minute: 1),
        bank(
          amount: 300000,
          income: false,
          minute: 2,
          debtType: DebtType.lend,
        ),
        bank(amount: 50000, income: false, minute: 3, excluded: true),
        bank(amount: 100000, income: false, minute: 4, isTransfer: true),
        bank(amount: 50000, income: true, balance: 500000, minute: 5),
      ]);

      expect(audit.isClean, isTrue);
    });

    test('tiền mặt không tham gia đối soát', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 900000, minute: 1),
        cash(amount: 500000, income: false, minute: 2),
        bank(amount: 100000, income: false, balance: 800000, minute: 3),
      ]);

      expect(audit.isClean, isTrue);
      expect(audit.checked, 2);
    });

    test('mỗi ngân hàng là một chuỗi riêng, không trộn vào nhau', () {
      final audit = auditLedger([
        bank(name: 'VCB', amount: 100000, income: false, balance: 900000, minute: 1),
        bank(name: 'MB', amount: 100000, income: false, balance: 500000, minute: 2),
        bank(name: 'VCB', amount: 100000, income: false, balance: 800000, minute: 3),
        bank(name: 'MB', amount: 100000, income: false, balance: 400000, minute: 4),
      ]);

      expect(audit.isClean, isTrue);
      expect(audit.banks.length, 2);
    });

    test('ngân hàng chưa từng gửi số dư thì xếp vào vùng không kiểm được', () {
      final audit = auditLedger([
        bank(name: 'MoMo', amount: 100000, income: false, minute: 1),
        bank(name: 'MoMo', amount: 200000, income: false, minute: 2),
      ]);

      expect(audit.unverifiable, ['MoMo']);
      expect(audit.banks, isEmpty);
      expect(audit.hasNothingToCheck, isFalse);
    });

    test('giao dịch trước mốc số dư đầu tiên không bị đem ra soi', () {
      final audit = auditLedger([
        // Không biết số dư trước khoản này nên không có gì để đối chiếu.
        bank(amount: 999999, income: false, minute: 1),
        bank(amount: 100000, income: false, balance: 900000, minute: 2),
        bank(amount: 100000, income: false, balance: 800000, minute: 3),
      ]);

      expect(audit.isClean, isTrue);
    });

    test('quá nửa mắt xích lệch thì coi là chuỗi không đáng tin', () {
      // Hai tài khoản chung một tên: số dư của chúng xen kẽ nhau.
      final audit = auditLedger([
        bank(amount: 10000, income: false, balance: 900000, minute: 1),
        bank(amount: 10000, income: false, balance: 200000, minute: 2),
        bank(amount: 10000, income: false, balance: 880000, minute: 3),
        bank(amount: 10000, income: false, balance: 180000, minute: 4),
        bank(amount: 10000, income: false, balance: 860000, minute: 5),
      ]);

      expect(audit.banks.single.unreliable, isTrue);
      // Chỗ hở của chuỗi hỏng không được đề nghị bù.
      expect(audit.gaps, isEmpty);
      expect(audit.suspicious, isEmpty);
    });

    test('chênh lệch ròng cộng dồn mọi chỗ hở', () {
      final audit = auditLedger([
        bank(amount: 100000, income: false, balance: 1000000, minute: 1),
        bank(amount: 100000, income: false, balance: 880000, minute: 2),
        bank(amount: 100000, income: false, balance: 750000, minute: 3),
      ]);

      expect(audit.gapCount, 2);
      expect(audit.netMissing, -50000);
    });

    test('không có giao dịch nào thì không kết luận gì', () {
      final audit = auditLedger(const <Txn>[]);
      expect(audit.hasNothingToCheck, isTrue);
      expect(audit.isClean, isFalse);
    });
  });
}
