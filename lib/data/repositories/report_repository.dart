import '../../core/date_range.dart';
import '../../domain/digest.dart' as digests;
import '../../domain/ledger_audit.dart' as ledger;
import '../../models/models.dart';
import '../dao/txn_dao.dart';

/// Số liệu tổng hợp cho màn chính và màn Báo cáo.
///
/// Việc gộp nhiều truy vấn thành một kết quả nằm ở đây chứ không ở UI — màn
/// hình chỉ nhận đúng thứ nó cần vẽ.
class ReportRepository {
  ReportRepository(this._dao);

  static const int defaultTrendMonths = 6;

  final TxnDao _dao;

  /// Tiền đang có ở cả hai ví.
  Future<WalletBalances> wallets() async {
    final cash = await _dao.cashBalance();
    final banks = await _dao.latestBankBalances();
    return WalletBalances(cash: cash, banks: banks);
  }

  /// Toàn bộ số liệu của một tháng. Truy vấn xu hướng lùi thêm một tháng so
  /// với khung hiển thị để luôn có số của tháng trước mà so sánh.
  /// [now] chỉ để test đặt được "hôm nay" — chạy thật thì bỏ trống.
  Future<MonthReport> monthReport(
    DateTime month, {
    int trendMonths = defaultTrendMonths,
    DateTime? now,
  }) async {
    final current = startOfMonth(month);
    final previous = shiftMonth(current, -1);
    final range = DateRange.month(current);

    final byCategory = await _dao.expenseByCategory(range);
    final history = await _dao.monthlyTotals(
      DateRange.monthsUpTo(current, trendMonths + 1),
    );
    final top = await _dao.topSpending(range);

    final trendFrom = shiftMonth(current, -(trendMonths - 1));
    final thisMonth = _monthIn(history, current);
    final lastMonth = _monthIn(history, previous);
    return MonthReport(
      byCategory: byCategory,
      trend: history.where((t) => !t.month.isBefore(trendFrom)).toList(),
      topSpending: top,
      current: thisMonth,
      previous: lastMonth,
      forecast: thisMonth == null
          ? null
          : MonthForecast.of(
              month: current,
              spent: thisMonth.expense,
              now: now ?? DateTime.now(),
              previousTotal: lastMonth?.expense,
            ),
    );
  }

  /// Bản tổng kết một kỳ, kèm so sánh với kỳ liền trước.
  ///
  /// [at] chọn kỳ (mặc định là kỳ đang diễn ra) và cũng là mốc "bây giờ" để
  /// biết kỳ đã trôi được bao nhiêu ngày.
  Future<Digest> digest(DigestPeriod period, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final range = period == DigestPeriod.week
        ? DateRange.week(now)
        : DateRange.month(now);
    final before = period == DigestPeriod.week
        ? DateRange.week(shiftWeek(range.from, -1))
        : DateRange.month(shiftMonth(range.from, -1));

    return digests.buildDigest(
      period: period,
      range: range,
      current: await _dao.inRange(range),
      previous: await _dao.inRange(before),
      now: now,
    );
  }

  /// Soi chuỗi số dư của từng ngân hàng để tìm giao dịch app đã bỏ lỡ.
  /// Không truyền [range] là kiểm cả lịch sử.
  Future<LedgerAudit> auditLedger({DateRange? range}) async =>
      ledger.auditLedger(await _dao.bankChain(range: range));

  /// Tháng không có giao dịch nào thì không có dòng nào trong kết quả truy vấn.
  static MonthlyTotal? _monthIn(List<MonthlyTotal> totals, DateTime month) {
    for (final entry in totals) {
      if (entry.month == month) return entry;
    }
    return null;
  }
}
