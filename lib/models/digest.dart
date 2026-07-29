import 'txn.dart';

/// Kỳ tổng kết.
enum DigestPeriod { week, month }

extension DigestPeriodX on DigestPeriod {
  String get label => this == DigestPeriod.week ? 'Tuần này' : 'Tháng này';

  String get pastLabel =>
      this == DigestPeriod.week ? 'tuần trước' : 'tháng trước';
}

/// Một nhóm chi tiêu thay đổi thế nào so với kỳ trước.
class CategoryShift {
  const CategoryShift({
    required this.category,
    required this.now,
    required this.before,
  });

  final String category;
  final int now;
  final int before;

  int get diff => now - before;

  /// Tăng bao nhiêu phần trăm. `null` khi kỳ trước không tiêu đồng nào cho
  /// nhóm này — lúc đó phần trăm là vô nghĩa, phải nói bằng số tiền.
  int? get percent => before == 0 ? null : (diff / before * 100).round();

  bool get isNew => before == 0 && now > 0;
}

/// Tiêu bao nhiêu trong một ngày.
class DaySpend {
  const DaySpend({required this.day, required this.total});

  final DateTime day;
  final int total;
}

/// Bản tổng kết một kỳ: đã tiêu bao nhiêu, vào đâu, và khác kỳ trước chỗ nào.
///
/// Màn Báo cáo trả lời "tiền đi đâu", bản tổng kết trả lời "có gì đổi khác" —
/// một biểu đồ tròn đẹp mấy cũng không nói được rằng tháng này tự dưng tiêu
/// gấp đôi cho việc đi lại.
class Digest {
  const Digest({
    required this.period,
    required this.from,
    required this.to,
    required this.spent,
    required this.income,
    required this.previousSpent,
    required this.txnCount,
    required this.shifts,
    required this.daysCovered,
    required this.noSpendDays,
    this.biggest,
    this.busiestDay,
  });

  final DigestPeriod period;

  /// Kỳ này là khoảng `[from, to)`.
  final DateTime from;
  final DateTime to;

  final int spent;
  final int income;

  /// Đã chi trong cùng độ dài ở kỳ trước.
  final int previousSpent;

  final int txnCount;

  /// Các nhóm đổi nhiều nhất, đổi mạnh nhất đứng trước.
  final List<CategoryShift> shifts;

  /// Số ngày đã trôi qua trong kỳ — kỳ đang dở thì ngắn hơn cả kỳ.
  final int daysCovered;

  /// Số ngày không tiêu đồng nào.
  final int noSpendDays;

  /// Khoản chi lớn nhất trong kỳ.
  final Txn? biggest;

  /// Ngày tiêu nhiều nhất.
  final DaySpend? busiestDay;

  bool get isEmpty => txnCount == 0;

  int get net => income - spent;

  int get diff => spent - previousSpent;

  int? get percent =>
      previousSpent == 0 ? null : (diff / previousSpent * 100).round();

  /// Trung bình mỗi ngày đã trôi qua.
  int get dailyRate => daysCovered == 0 ? 0 : spent ~/ daysCovered;

  /// Nhóm tăng mạnh nhất — thứ đáng nói nhất trong một bản tổng kết.
  CategoryShift? get biggestRise {
    for (final shift in shifts) {
      if (shift.diff > 0) return shift;
    }
    return null;
  }

  /// Nhóm giảm mạnh nhất.
  CategoryShift? get biggestDrop {
    CategoryShift? best;
    for (final shift in shifts) {
      if (shift.diff < 0 && (best == null || shift.diff < best.diff)) {
        best = shift;
      }
    }
    return best;
  }
}
