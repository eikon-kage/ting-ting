import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/core/date_range.dart';
import 'package:ting_ting/domain/digest.dart';
import 'package:ting_ting/models/models.dart';

/// Tuần 20–26/07/2026 bắt đầu vào thứ Hai 20/07.
final DateTime monday = DateTime(2026, 7, 20);

Txn spend({
  required int amount,
  required DateTime at,
  String category = 'Ăn uống',
  bool income = false,
  bool excluded = false,
  DebtType? debtType,
}) => Txn(
  packageName: 'com.vcb',
  bankName: 'VCB',
  direction: income ? TxnDirection.income : TxnDirection.expense,
  amount: amount,
  category: category,
  rawTitle: '',
  rawContent: '',
  postTime: at,
  excluded: excluded,
  debtType: debtType,
  person: debtType == null ? null : 'Bố',
);

Digest week({
  required List<Txn> current,
  List<Txn> previous = const [],
  required DateTime now,
}) => buildDigest(
  period: DigestPeriod.week,
  range: DateRange.week(now),
  current: current,
  previous: previous,
  now: now,
);

void main() {
  group('Mốc tuần', () {
    test('tuần bắt đầu từ thứ Hai', () {
      expect(startOfWeek(DateTime(2026, 7, 22, 15)), monday);
      expect(startOfWeek(monday), monday);
      // Chủ Nhật 26/07 vẫn thuộc tuần bắt đầu 20/07.
      expect(startOfWeek(DateTime(2026, 7, 26, 23)), monday);
    });

    test('khoảng một tuần dài đúng bảy ngày', () {
      final range = DateRange.week(DateTime(2026, 7, 22));
      expect(range.from, monday);
      expect(range.to, DateTime(2026, 7, 27));
    });

    test('lùi tuần vẫn đúng khi tràn tháng', () {
      expect(shiftWeek(DateTime(2026, 8, 3), -1), DateTime(2026, 7, 27));
    });
  });

  group('Bản tổng kết', () {
    test('cộng chi và thu, bỏ khoản nợ và khoản không tính', () {
      final digest = week(
        now: DateTime(2026, 7, 22, 18),
        current: [
          spend(amount: 200000, at: DateTime(2026, 7, 20, 12)),
          spend(amount: 300000, at: DateTime(2026, 7, 21, 12)),
          spend(amount: 5000000, at: DateTime(2026, 7, 21, 13), income: true),
          spend(amount: 900000, at: DateTime(2026, 7, 22, 9), excluded: true),
          spend(
            amount: 400000,
            at: DateTime(2026, 7, 22, 10),
            debtType: DebtType.lend,
          ),
        ],
      );

      expect(digest.spent, 500000);
      expect(digest.income, 5000000);
      expect(digest.net, 4500000);
      expect(digest.txnCount, 2);
    });

    test('kỳ đang dở thì chỉ tính số ngày đã trôi qua', () {
      // Thứ Tư 22/07: đã qua 3 ngày trong tuần.
      final digest = week(
        now: DateTime(2026, 7, 22, 18),
        current: [spend(amount: 300000, at: DateTime(2026, 7, 20, 12))],
      );

      expect(digest.daysCovered, 3);
      expect(digest.dailyRate, 100000);
    });

    test('kỳ trước bị cắt đúng số ngày ấy để so cho công bằng', () {
      // Mới tới thứ Tư. Tuần trước tiêu 300k trong 3 ngày đầu, rồi 9tr vào
      // thứ Bảy — phần sau không được đem ra so.
      final digest = week(
        now: DateTime(2026, 7, 22, 18),
        current: [spend(amount: 500000, at: DateTime(2026, 7, 20, 12))],
        previous: [
          spend(amount: 300000, at: DateTime(2026, 7, 14, 12)),
          spend(amount: 9000000, at: DateTime(2026, 7, 18, 12)),
        ],
      );

      expect(digest.previousSpent, 300000);
      expect(digest.diff, 200000);
    });

    test('kỳ đã khép lại thì so trọn vẹn cả hai bên', () {
      // Nhìn lại tuần 20–26/07 từ ngày 05/08: tuần ấy đã đủ bảy ngày.
      final digest = buildDigest(
        period: DigestPeriod.week,
        range: DateRange.week(monday),
        now: DateTime(2026, 8, 5),
        current: [spend(amount: 500000, at: DateTime(2026, 7, 20, 12))],
        previous: [spend(amount: 9000000, at: DateTime(2026, 7, 18, 12))],
      );

      expect(digest.daysCovered, 7);
      expect(digest.previousSpent, 9000000);
    });

    test('chỉ ra nhóm tăng mạnh nhất', () {
      final digest = week(
        now: DateTime(2026, 7, 26, 23),
        current: [
          spend(amount: 2000000, at: DateTime(2026, 7, 21), category: 'Đi lại'),
          spend(amount: 500000, at: DateTime(2026, 7, 22)),
        ],
        previous: [
          spend(amount: 400000, at: DateTime(2026, 7, 14), category: 'Đi lại'),
          spend(amount: 500000, at: DateTime(2026, 7, 15)),
        ],
      );

      final rise = digest.biggestRise!;
      expect(rise.category, 'Đi lại');
      expect(rise.diff, 1600000);
      expect(rise.percent, 400);
      expect(rise.isNew, isFalse);
    });

    test('nhóm mới toanh được đánh dấu riêng, không tính phần trăm', () {
      final digest = week(
        now: DateTime(2026, 7, 26, 23),
        current: [
          spend(amount: 700000, at: DateTime(2026, 7, 21), category: 'Giải trí'),
        ],
      );

      final rise = digest.biggestRise!;
      expect(rise.isNew, isTrue);
      expect(rise.percent, isNull);
    });

    test('chỉ ra nhóm giảm mạnh nhất', () {
      final digest = week(
        now: DateTime(2026, 7, 26, 23),
        current: [spend(amount: 100000, at: DateTime(2026, 7, 21))],
        previous: [spend(amount: 900000, at: DateTime(2026, 7, 14))],
      );

      expect(digest.biggestDrop!.diff, -800000);
      expect(digest.biggestRise, isNull);
    });

    test('tìm ra khoản lớn nhất và ngày tiêu nhiều nhất', () {
      final digest = week(
        now: DateTime(2026, 7, 26, 23),
        current: [
          spend(amount: 100000, at: DateTime(2026, 7, 20, 8)),
          spend(amount: 800000, at: DateTime(2026, 7, 21, 9)),
          spend(amount: 300000, at: DateTime(2026, 7, 21, 20)),
        ],
      );

      expect(digest.biggest!.amount, 800000);
      expect(digest.busiestDay!.day, DateTime(2026, 7, 21));
      expect(digest.busiestDay!.total, 1100000);
    });

    test('đếm ngày không tiêu đồng nào trong phần đã trôi qua', () {
      // Tới hết Chủ Nhật: 7 ngày, chỉ tiêu 2 ngày.
      final digest = week(
        now: DateTime(2026, 7, 26, 23),
        current: [
          spend(amount: 100000, at: DateTime(2026, 7, 20, 8)),
          spend(amount: 100000, at: DateTime(2026, 7, 23, 8)),
        ],
      );

      expect(digest.noSpendDays, 5);
    });

    test('không có khoản chi nào thì bản tổng kết rỗng', () {
      final digest = week(now: DateTime(2026, 7, 22), current: const []);
      expect(digest.isEmpty, isTrue);
      expect(digest.biggest, isNull);
      expect(digest.busiestDay, isNull);
      expect(digest.dailyRate, 0);
    });

    test('kỳ trước không có gì thì không tính phần trăm', () {
      final digest = week(
        now: DateTime(2026, 7, 22),
        current: [spend(amount: 100000, at: DateTime(2026, 7, 20))],
      );
      expect(digest.percent, isNull);
      expect(digest.diff, 100000);
    });
  });

  group('Tổng kết tháng', () {
    test('so với cùng số ngày đầu tháng trước', () {
      final digest = buildDigest(
        period: DigestPeriod.month,
        range: DateRange.month(DateTime(2026, 7)),
        now: DateTime(2026, 7, 10, 20),
        current: [spend(amount: 1000000, at: DateTime(2026, 7, 3))],
        previous: [
          spend(amount: 400000, at: DateTime(2026, 6, 5)),
          // Ngày 20/06 nằm ngoài 10 ngày đầu, không đem ra so.
          spend(amount: 8000000, at: DateTime(2026, 6, 20)),
        ],
      );

      expect(digest.daysCovered, 10);
      expect(digest.previousSpent, 400000);
      expect(digest.diff, 600000);
    });
  });
}
