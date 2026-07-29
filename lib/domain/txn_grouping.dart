import '../core/date_range.dart';
import '../models/models.dart';

/// Gom danh sách giao dịch theo ngày, giữ nguyên thứ tự mới nhất trước.
///
/// Danh sách vào phải đã sắp xếp giảm dần theo thời gian (repository trả về
/// đúng như vậy) nên chỉ cần duyệt một lượt.
List<DayGroup> groupTxnsByDay(List<Txn> txns) {
  final groups = <DayGroup>[];
  var dayTxns = <Txn>[];
  DateTime? currentDay;
  var net = 0;

  void flush() {
    if (currentDay == null) return;
    groups.add(DayGroup(day: currentDay!, txns: dayTxns, net: net));
  }

  for (final txn in txns) {
    final day = startOfDay(txn.postTime);
    if (day != currentDay) {
      flush();
      currentDay = day;
      dayTxns = <Txn>[];
      net = 0;
    }
    dayTxns.add(txn);
    if (txn.countsInReport) net += txn.signedAmount;
  }
  flush();
  return groups;
}

/// Số dư nợ của một tập giao dịch nợ. Dương = họ đang nợ mình.
int debtBalanceOf(Iterable<Txn> txns) =>
    txns.fold(0, (sum, txn) => sum + txn.debtEffect);

/// Tổng ròng (thu trừ chi) của một tập giao dịch, chỉ tính khoản vào báo cáo.
int netOf(Iterable<Txn> txns) => txns
    .where((t) => t.countsInReport)
    .fold(0, (sum, txn) => sum + txn.signedAmount);
