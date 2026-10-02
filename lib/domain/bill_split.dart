import '../models/models.dart';

/// Chia tiền một cuộc ăn chung / đi chơi chung: ai đã trả những gì, cuối cùng
/// ai phải đưa cho ai bao nhiêu.
///
/// Toàn bộ phần tính nằm ở đây, không dính database lẫn Flutter.

/// Chia đều [amount] cho [people].
///
/// Phần lẻ (100.000 chia ba) được dồn từng đồng cho những người đứng đầu danh
/// sách, để tổng các phần luôn khớp đúng [amount]. Làm tròn kiểu nào thì cũng
/// có người chịu thiệt một đồng, nhưng không được phép để cả nhóm cộng lại
/// thiếu mất tiền so với hoá đơn.
Map<String, int> splitEqually(int amount, List<String> people) {
  if (people.isEmpty) return const {};
  final base = amount ~/ people.length;
  var remainder = amount - base * people.length;
  final result = <String, int>{};
  for (final person in people) {
    result[person] = remainder > 0 ? base + 1 : base;
    if (remainder > 0) remainder--;
  }
  return result;
}

/// Số tiền từng người phải gánh ở một mục.
///
/// [members] là toàn bộ thành viên của bill: mục không chỉ đích danh ai thì
/// mặc định cả nhóm cùng gánh.
///
/// Ở chế độ tuỳ chỉnh, phần chưa gán cho ai rơi vào người đã trả. Nhờ vậy tổng
/// phần gánh luôn bằng đúng số tiền của mục dù user gõ thiếu, và bước chốt sổ
/// không bao giờ ra một bảng lệch.
Map<String, int> itemShares(BillItem item, List<String> members) {
  final named = item.people;
  if (item.mode == BillSplitMode.equal || named.isEmpty) {
    return splitEqually(item.amount, named.isEmpty ? members : named);
  }
  final owed = <String, int>{};
  for (final share in item.shares) {
    owed[share.person] = (owed[share.person] ?? 0) + (share.amount ?? 0);
  }
  final leftover = item.amount - item.assigned;
  if (leftover != 0) {
    owed[item.payer] = (owed[item.payer] ?? 0) + leftover;
  }
  return owed;
}

/// Một người trong bill: đã trả bao nhiêu, phải gánh bao nhiêu.
class BillMemberTotal {
  const BillMemberTotal({
    required this.person,
    required this.paid,
    required this.owed,
  });

  final String person;

  /// Số tiền người này đã móc ra trả cho cả nhóm.
  final int paid;

  /// Phần thật sự của người này trong tổng hoá đơn.
  final int owed;

  /// Dương = trả hộ nhiều hơn phần mình, đang được nhóm nợ.
  int get net => paid - owed;
}

/// Một lần đưa tiền để chốt sổ.
class BillTransfer {
  const BillTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });

  /// Người phải đưa tiền.
  final String from;

  /// Người nhận.
  final String to;

  final int amount;
}

/// Kết quả chốt sổ một bill.
class BillSettlement {
  const BillSettlement({
    required this.total,
    required this.members,
    required this.transfers,
  });

  static const empty = BillSettlement(total: 0, members: [], transfers: []);

  /// Tổng tiền cả bill.
  final int total;

  /// Từng người, xếp theo phần được nhận nhiều nhất trước.
  final List<BillMemberTotal> members;

  /// Danh sách "ai đưa ai bao nhiêu" đã rút gọn.
  final List<BillTransfer> transfers;

  BillMemberTotal? memberOf(String person) {
    for (final member in members) {
      if (member.person == person) return member;
    }
    return null;
  }

  /// Phần của chính mình — đây mới là con số mình thật sự tiêu trong cuộc này,
  /// không phải số tiền mình đã quẹt thẻ.
  int get myShare => memberOf(Bill.me)?.owed ?? 0;

  /// Dương = mình được nhận lại, âm = mình còn phải đưa.
  int get myNet => memberOf(Bill.me)?.net ?? 0;

  /// Những lần đưa tiền có mặt mình.
  List<BillTransfer> get myTransfers => [
    for (final transfer in transfers)
      if (transfer.from == Bill.me || transfer.to == Bill.me) transfer,
  ];
}

/// Một bill kèm kết quả chốt sổ — đủ để vẽ một dòng ở màn danh sách mà không
/// phải mở từng bill ra tính lại.
class BillOverview {
  const BillOverview({required this.bill, required this.settlement});

  final Bill bill;
  final BillSettlement settlement;
}

/// Chốt sổ: cộng phần của từng người rồi rút gọn thành ít lần đưa tiền nhất.
BillSettlement settleBill(Bill bill, List<BillItem> items) {
  final paid = <String, int>{};
  final owed = <String, int>{};
  // Người bị gỡ khỏi bill sau khi mục đã ghi vẫn phải có mặt, nếu không phần
  // của họ biến mất và bảng chốt sổ lệch đi đúng chừng ấy tiền.
  final people = Bill.mergeMembers(bill.members, [
    for (final item in items) ...[item.payer, ...item.people],
  ]);
  for (final person in people) {
    paid[person] = 0;
    owed[person] = 0;
  }

  var total = 0;
  for (final item in items) {
    total += item.amount;
    paid[item.payer] = (paid[item.payer] ?? 0) + item.amount;
    itemShares(item, bill.members).forEach((person, amount) {
      owed[person] = (owed[person] ?? 0) + amount;
    });
  }

  final members =
      [
        for (final person in people)
          BillMemberTotal(
            person: person,
            paid: paid[person] ?? 0,
            owed: owed[person] ?? 0,
          ),
      ]..sort((a, b) {
        final byNet = b.net.compareTo(a.net);
        return byNet != 0 ? byNet : a.person.compareTo(b.person);
      });

  return BillSettlement(
    total: total,
    members: members,
    transfers: _minimalTransfers(members),
  );
}

/// Ghép người đang được nợ nhiều nhất với người đang nợ nhiều nhất, lặp tới
/// khi mọi số dư về 0.
///
/// Cách này không phải lúc nào cũng cho ra số lần chuyển ít nhất tuyệt đối —
/// bài toán đó là NP-hard — nhưng luôn không quá `số người - 1` lần, đủ tốt
/// cho một nhóm đi chơi và quan trọng hơn là kết quả đoán trước được.
List<BillTransfer> _minimalTransfers(List<BillMemberTotal> members) {
  final creditors = <String, int>{};
  final debtors = <String, int>{};
  for (final member in members) {
    if (member.net > 0) creditors[member.person] = member.net;
    if (member.net < 0) debtors[member.person] = -member.net;
  }
  final transfers = <BillTransfer>[];
  // [members] đã xếp sẵn theo net giảm dần nên hai danh sách này cũng đã đúng
  // thứ tự "nhiều nhất trước".
  final owing = debtors.keys.toList().reversed.toList();
  final owed = creditors.keys.toList();

  var i = 0;
  var j = 0;
  while (i < owing.length && j < owed.length) {
    final from = owing[i];
    final to = owed[j];
    final amount = debtors[from]! < creditors[to]!
        ? debtors[from]!
        : creditors[to]!;
    if (amount > 0) {
      transfers.add(BillTransfer(from: from, to: to, amount: amount));
      debtors[from] = debtors[from]! - amount;
      creditors[to] = creditors[to]! - amount;
    }
    if (debtors[from] == 0) i++;
    if (creditors[to] == 0) j++;
  }
  return transfers;
}
