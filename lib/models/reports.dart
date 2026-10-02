import 'category.dart';
import 'txn.dart';

/// Tổng chi của một nhóm trong kỳ báo cáo.
class CategoryTotal {
  const CategoryTotal({required this.category, required this.total});

  final String category;
  final int total;
}

/// Thu và chi của một tháng.
class MonthlyTotal {
  const MonthlyTotal({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final int income;
  final int expense;

  int get net => income - expense;
}

/// Một nơi tiêu tiền, gom theo nội dung giao dịch.
class SpendingSpot {
  const SpendingSpot({
    required this.label,
    required this.total,
    required this.count,
  });

  final String label;
  final int total;
  final int count;
}

/// Số dư mới nhất của một ngân hàng, kèm thời điểm ghi nhận.
class BankBalance {
  const BankBalance({
    required this.bankName,
    required this.balance,
    required this.at,
  });

  final String bankName;
  final int balance;
  final DateTime at;
}

/// Tiền đang có, tách theo hai ví.
class WalletBalances {
  const WalletBalances({required this.cash, required this.banks});

  static const empty = WalletBalances(cash: 0, banks: []);

  final int cash;
  final List<BankBalance> banks;

  int get bankTotal => banks.fold(0, (sum, b) => sum + b.balance);

  bool get hasBankData => banks.isNotEmpty;
}

/// Tổng thu / chi của một tập giao dịch.
class TxnTotals {
  const TxnTotals({
    required this.income,
    required this.expense,
    this.shareBill = 0,
    this.borrowed = 0,
  });

  static const zero = TxnTotals(income: 0, expense: 0);

  /// Chỉ cộng giao dịch được tính vào báo cáo — bỏ nợ, chuyển ví, khoản đã loại.
  factory TxnTotals.of(Iterable<Txn> txns) {
    var income = 0;
    var expense = 0;
    var shareBill = 0;
    var borrowed = 0;
    for (final txn in txns) {
      if (!txn.countsInReport) continue;
      if (txn.direction == TxnDirection.income) {
        income += txn.amount;
        final kind = txn.incomeKind;
        if (kind == IncomeKind.shareBill) shareBill += txn.amount;
        if (kind == IncomeKind.borrowed) borrowed += txn.amount;
      } else {
        expense += txn.amount;
      }
    }
    return TxnTotals(
      income: income,
      expense: expense,
      shareBill: shareBill,
      borrowed: borrowed,
    );
  }

  /// Toàn bộ tiền vào, cả ba kiểu. Đây là số tiền thật sự chạy vào ví trong kỳ
  /// nên nó phải trọn vẹn; muốn biết bao nhiêu là của mình thì xem [earned].
  final int income;

  final int expense;

  /// Phần [income] là người cùng bill trả lại phần của họ.
  final int shareBill;

  /// Phần [income] là tiền mình vay của người khác.
  final int borrowed;

  /// Tiền mình thật sự kiếm được trong kỳ.
  int get earned => income - shareBill - borrowed;

  int get net => income - expense;

  /// Số mình thật sự tiêu: ứng một triệu trả cả bàn rồi được trả lại bảy trăm
  /// nghìn thì mình tiêu ba trăm nghìn, không phải một triệu.
  ///
  /// Chặn ở 0 vì tiền chia bill hay về sau khoản chi cả một kỳ — thu tháng này
  /// phần bữa ăn tháng trước là chuyện thường, mà "đã chi âm" thì vô nghĩa.
  int get netExpense => expense > shareBill ? expense - shareBill : 0;
}

/// Giao dịch của một ngày, kèm số dư ròng trong ngày đó.
class DayGroup {
  const DayGroup({required this.day, required this.txns, required this.net});

  final DateTime day;
  final List<Txn> txns;

  /// Thu trừ chi trong ngày, chỉ tính giao dịch vào báo cáo.
  final int net;
}

/// Số dư nợ với một người. Dương = họ đang nợ mình.
class DebtSummary {
  const DebtSummary({
    required this.person,
    required this.balance,
    required this.count,
  });

  final String person;
  final int balance;
  final int count;

  bool get theyOweMe => balance >= 0;
}

/// Toàn cảnh sổ nợ.
class DebtOverview {
  const DebtOverview({required this.people, required this.unassigned});

  static const empty = DebtOverview(people: [], unassigned: []);

  final List<DebtSummary> people;

  /// Giao dịch đã đánh dấu là nợ nhưng chưa gán tên người.
  final List<Txn> unassigned;

  int get theyOweMe =>
      people.where((p) => p.balance > 0).fold(0, (sum, p) => sum + p.balance);

  int get iOweThem =>
      people.where((p) => p.balance < 0).fold(0, (sum, p) => sum - p.balance);

  bool get isEmpty => people.isEmpty && unassigned.isEmpty;
}

/// Tháng này đang đi về đâu.
///
/// Con số "đã chi" giữa tháng không tự nó nói lên điều gì: 7 triệu vào ngày 10
/// là nhiều hay ít thì còn tuỳ. Kéo dài nhịp chi hiện tại tới cuối tháng mới ra
/// được câu trả lời, và mới kịp phanh khi còn phanh được.
class MonthForecast {
  const MonthForecast({
    required this.month,
    required this.spent,
    required this.daysElapsed,
    required this.daysInMonth,
    this.previousTotal,
  });

  /// Vài ngày đầu tháng thì một khoản tiền nhà cũng đủ kéo dự báo lên gấp mấy
  /// lần sự thật. Chưa đủ ngày thì không đoán còn hơn đoán bậy.
  static const int minDaysToTell = 3;

  /// Dựng dự báo cho [month] tại thời điểm [now].
  factory MonthForecast.of({
    required DateTime month,
    required int spent,
    required DateTime now,
    int? previousTotal,
  }) {
    final total = DateTime(month.year, month.month + 1, 0).day;
    final sameMonth = now.year == month.year && now.month == month.month;
    final elapsed = sameMonth
        ? now.day
        // Tháng đã qua thì trọn vẹn, tháng chưa tới thì chưa có ngày nào.
        : (now.isAfter(month) ? total : 0);
    return MonthForecast(
      month: month,
      spent: spent,
      daysElapsed: elapsed.clamp(0, total),
      daysInMonth: total,
      previousTotal: previousTotal,
    );
  }

  final DateTime month;

  /// Đã chi tính tới hôm nay.
  final int spent;

  final int daysElapsed;
  final int daysInMonth;

  /// Tổng chi cả tháng trước, để so. `null` khi tháng trước không có dữ liệu.
  final int? previousTotal;

  int get daysLeft => daysInMonth - daysElapsed;

  bool get isComplete => daysLeft <= 0;

  /// Đủ ngày và đủ số để nói một câu có nghĩa.
  bool get reliable => daysElapsed >= minDaysToTell && spent > 0;

  /// Trung bình mỗi ngày đã chi bao nhiêu.
  int get dailyRate => daysElapsed == 0 ? 0 : spent ~/ daysElapsed;

  /// Cuối tháng sẽ chi khoảng bao nhiêu nếu giữ nguyên nhịp này.
  int get projected {
    if (isComplete || daysElapsed == 0) return spent;
    return (spent / daysElapsed * daysInMonth).round();
  }

  /// Dự báo so với tháng trước. Dương = tiêu nhiều hơn.
  int? get diffVsPrevious =>
      previousTotal == null ? null : projected - previousTotal!;

  /// Còn được tiêu bao nhiêu mỗi ngày để không vượt tháng trước. `null` khi
  /// không có gì để so, âm khi đã lỡ vượt rồi.
  int? get dailyBudgetLeft {
    final target = previousTotal;
    if (target == null || daysLeft <= 0) return null;
    return (target - spent) ~/ daysLeft;
  }
}

/// Toàn bộ số liệu màn Báo cáo cần cho một tháng — lấy một lần, không để UI
/// phải ghép từ nhiều truy vấn rời rạc.
class MonthReport {
  const MonthReport({
    required this.byCategory,
    required this.trend,
    required this.topSpending,
    this.current,
    this.previous,
    this.forecast,
  });

  static const empty = MonthReport(
    byCategory: [],
    trend: [],
    topSpending: [],
  );

  final List<CategoryTotal> byCategory;

  /// Thu chi vài tháng gần nhất, cũ đến mới — dữ liệu cho biểu đồ cột.
  final List<MonthlyTotal> trend;
  final List<SpendingSpot> topSpending;

  /// Thu chi của chính tháng đang xem, `null` khi tháng đó chưa có giao dịch.
  final MonthlyTotal? current;

  /// Thu chi tháng liền trước, để so sánh.
  final MonthlyTotal? previous;

  /// Tháng đang xem sẽ kết thúc ở đâu. `null` khi tháng đó chưa có giao dịch.
  final MonthForecast? forecast;

  int get totalExpense => byCategory.fold(0, (sum, c) => sum + c.total);

  /// Chênh lệch chi so với tháng trước, `null` khi thiếu số của một trong hai.
  int? get expenseDiff => (current == null || previous == null)
      ? null
      : current!.expense - previous!.expense;
}
