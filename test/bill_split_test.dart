import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/bill_split.dart';
import 'package:ting_ting/models/models.dart';

const me = Bill.me;

Bill trip({List<String> others = const ['Nam', 'Lan']}) =>
    Bill.create(title: 'Đi Đà Lạt', others: others, at: DateTime(2026, 7, 30));

BillItem item({
  required int amount,
  required String payer,
  String label = 'Khoản',
  BillSplitMode mode = BillSplitMode.equal,
  List<BillShare> shares = const [],
  int seq = 0,
}) => BillItem.create(
  billKey: 'bill|1',
  label: label,
  amount: amount,
  payer: payer,
  mode: mode,
  shares: shares,
  at: DateTime(2026, 7, 30, 12, 0, seq),
);

/// Tổng số dư của cả nhóm phải bằng 0 — có người được nhận thì phải có người
/// đưa, không đồng nào được sinh ra hay biến mất trong lúc chia.
void expectBalanced(BillSettlement settlement) {
  expect(
    settlement.members.fold(0, (sum, member) => sum + member.net),
    0,
    reason: 'tổng số dư của nhóm phải bằng 0',
  );
}

void main() {
  group('splitEqually', () {
    test('chia hết thì ai cũng như ai', () {
      expect(splitEqually(900000, [me, 'Nam', 'Lan']), {
        me: 300000,
        'Nam': 300000,
        'Lan': 300000,
      });
    });

    test('phần lẻ dồn cho người đứng đầu, tổng vẫn khớp', () {
      final shares = splitEqually(100000, [me, 'Nam', 'Lan']);
      expect(shares[me], 33334);
      expect(shares['Nam'], 33333);
      expect(shares['Lan'], 33333);
      expect(shares.values.reduce((a, b) => a + b), 100000);
    });

    test('không có ai thì không chia cho ai', () {
      expect(splitEqually(50000, const []), isEmpty);
    });
  });

  group('Phần của từng người trong một khoản', () {
    test('không chỉ đích danh ai thì cả nhóm cùng gánh', () {
      final shares = itemShares(item(amount: 300000, payer: me), [
        me,
        'Nam',
        'Lan',
      ]);
      expect(shares, {me: 100000, 'Nam': 100000, 'Lan': 100000});
    });

    test('chia đều chỉ cho những người có tên trong khoản', () {
      final shares = itemShares(
        item(
          amount: 200000,
          payer: 'Nam',
          shares: const [BillShare('Nam'), BillShare('Lan')],
        ),
        [me, 'Nam', 'Lan'],
      );
      expect(shares, {'Nam': 100000, 'Lan': 100000});
    });

    test('mỗi người một khoản thì lấy đúng số đã gán', () {
      final shares = itemShares(
        item(
          amount: 350000,
          payer: 'Lan',
          mode: BillSplitMode.custom,
          shares: const [
            BillShare(me, 100000),
            BillShare('Nam', 100000),
            BillShare('Lan', 150000),
          ],
        ),
        [me, 'Nam', 'Lan'],
      );
      expect(shares, {me: 100000, 'Nam': 100000, 'Lan': 150000});
    });

    test('phần chưa gán cho ai thì người trả tự chịu', () {
      // Khoản 500.000 nhưng mới gán 300.000 — 200.000 còn lại về Nam.
      final shares = itemShares(
        item(
          amount: 500000,
          payer: 'Nam',
          mode: BillSplitMode.custom,
          shares: const [BillShare(me, 200000), BillShare('Lan', 100000)],
        ),
        [me, 'Nam', 'Lan'],
      );
      expect(shares, {me: 200000, 'Lan': 100000, 'Nam': 200000});
      expect(shares.values.reduce((a, b) => a + b), 500000);
    });
  });

  group('Chốt sổ một chuyến đi chơi', () {
    // Tôi trả bữa tối 900k, Nam trả taxi 300k, vé vào cổng 350k Lan trả và
    // mỗi người một giá.
    final items = [
      item(amount: 900000, payer: me, label: 'Ăn tối', seq: 1),
      item(amount: 300000, payer: 'Nam', label: 'Taxi', seq: 2),
      item(
        amount: 350000,
        payer: 'Lan',
        label: 'Vé vào cổng',
        mode: BillSplitMode.custom,
        shares: const [
          BillShare(me, 100000),
          BillShare('Nam', 100000),
          BillShare('Lan', 150000),
        ],
        seq: 3,
      ),
    ];
    final settlement = settleBill(trip(), items);

    test('tổng bill là tổng các khoản', () {
      expect(settlement.total, 1550000);
    });

    test('phần thật của mình không phải số tiền mình đã quẹt thẻ', () {
      // Đã trả 900.000 nhưng phần mình chỉ là 300k + 100k + 100k.
      expect(settlement.myShare, 500000);
      expect(settlement.memberOf(me)!.paid, 900000);
      expect(settlement.myNet, 400000);
    });

    test('cả nhóm cộng lại bằng 0', () {
      expectBalanced(settlement);
      expect(
        settlement.members.fold(0, (sum, member) => sum + member.owed),
        settlement.total,
      );
    });

    test('rút gọn thành ít lần đưa tiền, và đúng chiều', () {
      // Nam và Lan mỗi người thiếu 200.000, mình được nhận về 400.000.
      expect(settlement.transfers.length, 2);
      for (final transfer in settlement.transfers) {
        expect(transfer.to, me);
      }
      expect(settlement.transfers.fold(0, (sum, t) => sum + t.amount), 400000);
    });

    test('mỗi người chỉ xuất hiện đúng phần còn thiếu của mình', () {
      final byPerson = {
        for (final transfer in settlement.transfers)
          transfer.from: transfer.amount,
      };
      // Lan trả hộ 350.000 nhưng phần Lan là 550.000, nên vẫn còn thiếu.
      expect(byPerson['Lan'], 200000);
      expect(byPerson['Nam'], 200000);
    });
  });

  group('Chốt sổ những trường hợp lệch', () {
    test('cả nhóm hoà thì không phải đưa ai đồng nào', () {
      final settlement = settleBill(trip(others: const ['Nam']), [
        item(amount: 200000, payer: me, seq: 1),
        item(amount: 200000, payer: 'Nam', seq: 2),
      ]);
      expect(settlement.transfers, isEmpty);
      expect(settlement.myNet, 0);
    });

    test('bill chưa có khoản nào thì mọi con số là 0', () {
      final settlement = settleBill(trip(), const []);
      expect(settlement.total, 0);
      expect(settlement.transfers, isEmpty);
      expect(settlement.members.length, 3);
    });

    test('người đã bị gỡ khỏi bill vẫn được tính', () {
      // Khoản cũ còn ghi tên Lan trong khi Lan không còn trong danh sách.
      final settlement = settleBill(trip(others: const ['Nam']), [
        item(
          amount: 300000,
          payer: me,
          shares: const [BillShare(me), BillShare('Nam'), BillShare('Lan')],
          seq: 1,
        ),
      ]);
      expect(settlement.memberOf('Lan')?.owed, 100000);
      expectBalanced(settlement);
    });

    test('một người trả hết cho cả nhóm thì mỗi người trả lại một lần', () {
      final settlement = settleBill(trip(others: const ['Nam', 'Lan', 'Huy']), [
        item(amount: 400000, payer: me, seq: 1),
      ]);
      expect(settlement.transfers.length, 3);
      expect(settlement.myNet, 300000);
      expectBalanced(settlement);
    });

    test('phần lẻ không làm bảng chốt sổ lệch', () {
      final settlement = settleBill(trip(), [
        item(amount: 100000, payer: 'Nam', seq: 1),
      ]);
      expectBalanced(settlement);
      expect(
        settlement.transfers.fold(0, (sum, t) => sum + t.amount),
        settlement.memberOf('Nam')!.net,
      );
    });
  });

  group('Thành viên của bill', () {
    test('mình luôn có mặt và đứng đầu', () {
      final bill = trip();
      expect(bill.members.first, me);
      expect(bill.others, ['Nam', 'Lan']);
    });

    test('thêm trùng tên thì bỏ qua, không phân biệt hoa thường', () {
      expect(Bill.mergeMembers([me, 'Nam'], ['nam', 'Lan']), [
        me,
        'Nam',
        'Lan',
      ]);
    });

    test('tên rỗng và khoảng trắng thừa bị dọn', () {
      expect(Bill.mergeMembers(const [], ['  ', ' Chị   Lan ']), ['Chị Lan']);
    });

    test('dấu = và xuống dòng bị bỏ đi vì chúng là dấu phân cách lúc lưu', () {
      expect(Bill.sanitizeName('Nam=1\n2'), 'Nam 1 2');
    });
  });

  group('Lưu và đọc lại', () {
    test('bill đi qua database rồi về vẫn nguyên vẹn', () {
      final bill = trip().copyWith(settled: true);
      final back = Bill.fromMap(bill.toMap());
      expect(back.key, bill.key);
      expect(back.title, bill.title);
      expect(back.members, bill.members);
      expect(back.settled, isTrue);
      expect(back.createdAt, bill.createdAt);
    });

    test('khoản chia đều: chỉ tên người được lưu, số tiền tính lúc chốt', () {
      final saved = item(
        amount: 300000,
        payer: 'Nam',
        shares: const [BillShare(me), BillShare('Nam')],
      );
      expect(saved.toMap()['shares'], 'Tôi\nNam');
      final back = BillItem.fromMap(saved.toMap());
      expect(back.people, [me, 'Nam']);
      expect(back.shares.every((share) => share.amount == null), isTrue);
    });

    test('khoản mỗi người một khoản giữ đúng con số của từng người', () {
      final saved = item(
        amount: 350000,
        payer: 'Lan',
        mode: BillSplitMode.custom,
        shares: const [BillShare(me, 100000), BillShare('Lan', 250000)],
      );
      expect(saved.toMap()['shares'], 'Tôi=100000\nLan=250000');
      final back = BillItem.fromMap(saved.toMap());
      expect(back.mode, BillSplitMode.custom);
      expect(back.assigned, 350000);
      expect(back.shares.last.amount, 250000);
    });

    test('mỗi bill và mỗi khoản mang một khoá riêng', () {
      expect(
        item(amount: 1, payer: me, seq: 1).key,
        isNot(item(amount: 1, payer: me, seq: 2).key),
      );
    });
  });
}
