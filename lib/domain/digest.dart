import '../core/date_range.dart';
import '../models/models.dart';

/// Dựng bản tổng kết một kỳ từ giao dịch của kỳ đó và kỳ liền trước.
///
/// So sánh chỉ công bằng khi hai kỳ dài bằng nhau. Kỳ này còn đang dở — mới
/// tới thứ Tư, mới tới ngày 12 — nên kỳ trước cũng bị cắt đúng chừng ấy ngày.
/// Không cắt thì tuần nào cũng "tiêu ít hơn tuần trước" cho tới tận Chủ Nhật,
/// một lời khen sai mỗi tuần một lần.
///
/// [now] là thời điểm coi như "bây giờ"; kỳ đã khép lại thì nó không ảnh hưởng.
Digest buildDigest({
  required DigestPeriod period,
  required DateRange range,
  required Iterable<Txn> current,
  required Iterable<Txn> previous,
  required DateTime now,
}) {
  final elapsed = _daysElapsed(range, now);
  // Cùng số ngày ấy tính từ đầu kỳ trước.
  final cutoff = _plusDays(_shiftBack(period, range.from), elapsed);

  final spending = <Txn>[];
  var spent = 0;
  var income = 0;
  final byCategory = <String, int>{};
  final byDay = <DateTime, int>{};

  for (final txn in current) {
    if (!txn.countsInReport) continue;
    if (txn.direction == TxnDirection.income) {
      income += txn.amount;
      continue;
    }
    spent += txn.amount;
    spending.add(txn);
    byCategory[txn.category] = (byCategory[txn.category] ?? 0) + txn.amount;
    final day = startOfDay(txn.postTime);
    byDay[day] = (byDay[day] ?? 0) + txn.amount;
  }

  final beforeByCategory = <String, int>{};
  var previousSpent = 0;
  for (final txn in previous) {
    if (!txn.countsInReport) continue;
    if (txn.direction == TxnDirection.income) continue;
    if (!txn.postTime.isBefore(cutoff)) continue;
    previousSpent += txn.amount;
    beforeByCategory[txn.category] =
        (beforeByCategory[txn.category] ?? 0) + txn.amount;
  }

  final shifts = <CategoryShift>[
    for (final name in {...byCategory.keys, ...beforeByCategory.keys})
      CategoryShift(
        category: name,
        now: byCategory[name] ?? 0,
        before: beforeByCategory[name] ?? 0,
      ),
  ]..sort((a, b) => b.diff.abs().compareTo(a.diff.abs()));

  return Digest(
    period: period,
    from: range.from,
    to: range.to,
    spent: spent,
    income: income,
    previousSpent: previousSpent,
    txnCount: spending.length,
    shifts: shifts,
    daysCovered: elapsed,
    noSpendDays: elapsed - byDay.length,
    biggest: _largest(spending),
    busiestDay: _busiest(byDay),
  );
}

/// Số ngày của kỳ đã thật sự trôi qua, tính cả ngày hôm nay.
int _daysElapsed(DateRange range, DateTime now) {
  final total = range.to.difference(range.from).inDays;
  if (!range.contains(now)) {
    // Kỳ đã khép lại thì trọn vẹn; kỳ chưa tới thì chưa có ngày nào.
    return now.isBefore(range.from) ? 0 : total;
  }
  final done = startOfDay(now).difference(range.from).inDays + 1;
  return done.clamp(1, total);
}

/// Cộng ngày qua trường `day`, không cộng số giờ — cách kia lệch mất một tiếng
/// ở những nơi có đổi giờ.
DateTime _plusDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

DateTime _shiftBack(DigestPeriod period, DateTime from) =>
    period == DigestPeriod.week ? shiftWeek(from, -1) : shiftMonth(from, -1);

Txn? _largest(List<Txn> spending) {
  Txn? best;
  for (final txn in spending) {
    if (best == null || txn.amount > best.amount) best = txn;
  }
  return best;
}

DaySpend? _busiest(Map<DateTime, int> byDay) {
  MapEntry<DateTime, int>? best;
  for (final entry in byDay.entries) {
    if (best == null || entry.value > best.value) best = entry;
  }
  return best == null ? null : DaySpend(day: best.key, total: best.value);
}
