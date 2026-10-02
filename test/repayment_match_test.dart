import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/bill_split.dart';
import 'package:ting_ting/domain/repayment_match.dart';
import 'package:ting_ting/models/models.dart';

Txn incoming(int amount, String content, {String category = 'Lương'}) => Txn(
  packageName: 'com.vietcombank',
  bankName: 'Vietcombank',
  direction: TxnDirection.income,
  amount: amount,
  description: content,
  category: category,
  rawTitle: 'Biến động số dư',
  rawContent: content,
  postTime: DateTime(2026, 10, 2, 9),
);

/// A bill where I paid [amount] for me, Nam and Lan, split three ways.
BillOverview dinner({
  int amount = 900000,
  Map<String, int> repaid = const {},
  bool settled = false,
  DateTime? at,
  String title = 'Ăn lẩu',
}) {
  final bill = Bill.create(
    title: title,
    others: const ['Nam', 'Lan'],
    at: at ?? DateTime(2026, 9, 30),
  ).copyWith(repaid: repaid, settled: settled);
  final item = BillItem.create(
    billKey: bill.key,
    label: 'Lẩu',
    amount: amount,
    payer: Bill.me,
    mode: BillSplitMode.equal,
    shares: const [],
  );
  return BillOverview(bill: bill, settlement: settleBill(bill, [item]));
}

const namOwes = DebtSummary(person: 'Nam', balance: 500000, count: 1);

void main() {
  group('namesPerson', () {
    test('matches a capitalised sender without diacritics', () {
      expect(namesPerson('NGUYEN VAN NAM chuyen tien', 'Nam'), isTrue);
      expect(namesPerson('NGUYEN VAN NAM chuyen tien', 'Văn Nam'), isTrue);
    });

    test('needs whole words in order', () {
      expect(namesPerson('NAMA chuyen tien', 'Nam'), isFalse);
      expect(namesPerson('NAM VAN chuyen tien', 'Văn Nam'), isFalse);
    });

    test('an empty name matches nothing', () {
      expect(namesPerson('NGUYEN VAN NAM', '  '), isFalse);
    });
  });

  group('debt repayment', () {
    test('asks when amount and name both match', () {
      final match = matchRepayment(
        incoming(500000, 'NGUYEN VAN NAM tra tien'),
        debts: const [namOwes],
        bills: const [],
      );
      expect(match, isA<DebtRepaymentMatch>());
      expect(match!.person, 'Nam');
      expect(match.question, 'Đánh dấu Nam đã trả nợ?');
    });

    test('stays quiet when the amount differs', () {
      final match = matchRepayment(
        incoming(200000, 'NGUYEN VAN NAM tra tien'),
        debts: const [namOwes],
        bills: const [],
      );
      expect(match, isNull);
    });

    test('stays quiet when the sender is someone else', () {
      final match = matchRepayment(
        incoming(500000, 'TRAN THI LAN chuyen tien'),
        debts: const [namOwes],
        bills: const [],
      );
      expect(match, isNull);
    });

    test('ignores money going out', () {
      final txn = Txn(
        packageName: 'com.vietcombank',
        bankName: 'Vietcombank',
        direction: TxnDirection.expense,
        amount: 500000,
        category: 'Khác',
        rawTitle: '',
        rawContent: 'chuyen tien cho NGUYEN VAN NAM',
        postTime: DateTime(2026, 10, 2),
      );
      expect(
        matchRepayment(txn, debts: const [namOwes], bills: const []),
        isNull,
      );
    });

    test('ignores a debt the user owes, not one owed to them', () {
      final match = matchRepayment(
        incoming(500000, 'NGUYEN VAN NAM chuyen tien'),
        debts: const [DebtSummary(person: 'Nam', balance: -500000, count: 1)],
        bills: const [],
      );
      expect(match, isNull);
    });

    test('ignores a transaction already in the debt book', () {
      final txn = incoming(
        500000,
        'NGUYEN VAN NAM tra tien',
      ).copyWith(debtType: DebtType.collect, person: 'Nam');
      expect(
        matchRepayment(txn, debts: const [namOwes], bills: const []),
        isNull,
      );
    });

    test('says nothing when two people could be paying', () {
      final match = matchRepayment(
        incoming(500000, 'NAM va LAN chuyen tien'),
        debts: const [
          namOwes,
          DebtSummary(person: 'Lan', balance: 500000, count: 1),
        ],
        bills: const [],
      );
      expect(match, isNull);
    });
  });

  group('bill repayment', () {
    test('asks when the amount is what that person owes me', () {
      final match = matchRepayment(
        incoming(300000, 'NGUYEN VAN NAM tien lau'),
        debts: const [],
        bills: [dinner()],
      );
      expect(match, isA<BillRepaymentMatch>());
      expect(match!.person, 'Nam');
      expect(match.question, 'Đánh dấu Nam đã trả phần bill "Ăn lẩu"?');
    });

    test('skips a bill already marked done', () {
      final match = matchRepayment(
        incoming(300000, 'NGUYEN VAN NAM tien lau'),
        debts: const [],
        bills: [dinner(settled: true)],
      );
      expect(match, isNull);
    });

    test('skips a share that was already paid back', () {
      final match = matchRepayment(
        incoming(300000, 'NGUYEN VAN NAM tien lau'),
        debts: const [],
        bills: [
          dinner(repaid: const {'Nam': 300000}),
        ],
      );
      expect(match, isNull);
    });

    test('still asks when the note already put it in "Chia bill"', () {
      final match = matchRepayment(
        incoming(
          300000,
          'NGUYEN VAN NAM chia bill',
          category: Category.shareBill,
        ),
        debts: const [],
        bills: [dinner()],
      );
      expect(match, isA<BillRepaymentMatch>());
    });

    test('settles the oldest open bill first', () {
      final match = matchRepayment(
        incoming(300000, 'NGUYEN VAN NAM'),
        debts: const [],
        bills: [
          dinner(title: 'Mới', at: DateTime(2026, 10, 1)),
          dinner(title: 'Cũ', at: DateTime(2026, 9, 1)),
        ],
      );
      expect((match! as BillRepaymentMatch).bill.title, 'Cũ');
    });

    test('a debt of the same amount wins over a bill', () {
      final match = matchRepayment(
        incoming(300000, 'NGUYEN VAN NAM'),
        debts: const [DebtSummary(person: 'Nam', balance: 300000, count: 1)],
        bills: [dinner()],
      );
      expect(match, isA<DebtRepaymentMatch>());
    });
  });

  group('settlement with paybacks', () {
    test('a payback removes that transfer and lowers what I am owed', () {
      final settlement = dinner(repaid: const {'Nam': 300000}).settlement;

      expect(settlement.owedToMeBy('Nam'), 0);
      expect(settlement.owedToMeBy('Lan'), 300000);
      expect(settlement.myNet, 300000);
      expect(settlement.myShare, 300000);
      expect(settlement.total, 900000);
    });

    test('a partial payback leaves the rest outstanding', () {
      final settlement = dinner(repaid: const {'Nam': 100000}).settlement;
      expect(settlement.owedToMeBy('Nam'), 200000);
    });

    test('everyone paid back means no transfers left', () {
      final settlement = dinner(
        repaid: const {'Nam': 300000, 'Lan': 300000},
      ).settlement;
      expect(settlement.transfers, isEmpty);
      expect(settlement.myNet, 0);
    });
  });

  group('Bill.repaid storage', () {
    test('round-trips through the stored text', () {
      const repaid = {'Nam': 300000, 'Lan Anh': 150000};
      expect(Bill.decodeRepaid(Bill.encodeRepaid(repaid)), repaid);
    });

    test('an old row without the column reads as nothing repaid', () {
      expect(Bill.decodeRepaid(null), isEmpty);
    });

    test('withRepayment adds to what was already paid', () {
      final bill = dinner().bill.withRepayment('Nam', 100000);
      expect(bill.withRepayment('Nam', 200000).repaid, {'Nam': 300000});
    });
  });
}
