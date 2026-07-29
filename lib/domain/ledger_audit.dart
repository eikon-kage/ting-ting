import '../models/models.dart';

/// Đối soát chuỗi số dư để tìm giao dịch app đã bỏ lỡ.
///
/// App ghi sổ bằng cách đọc thông báo, mà thông báo thì không đảm bảo: máy tắt
/// nguồn, Android bóp tiến trình nền, hay hệ thống giấu nội dung nhạy cảm —
/// giao dịch biến mất khỏi sổ và không ai biết. Nhưng ngân hàng gửi kèm số dư
/// sau mỗi giao dịch, nên chính các con số đó tố cáo chỗ thiếu:
///
///     số dư sau = số dư trước + tổng các khoản đã ghi ở giữa
///
/// Lệch bao nhiêu là thiếu đúng bấy nhiêu tiền, và chắc chắn nó nằm trong
/// khoảng thời gian giữa hai giao dịch đó.
///
/// Chỉ ví ngân hàng mới đối soát được. Tiền mặt không có nguồn nào báo số dư,
/// nó vốn đã là tổng cộng dồn nên không bao giờ tự mâu thuẫn.
LedgerAudit auditLedger(Iterable<Txn> txns) {
  final byBank = <String, List<Txn>>{};
  for (final txn in txns) {
    if (txn.accountKind != AccountKind.bank) continue;
    byBank.putIfAbsent(txn.bankName, () => <Txn>[]).add(txn);
  }

  final banks = <BankLedger>[];
  final unverifiable = <String>[];
  var checked = 0;

  for (final entry in byBank.entries) {
    final chain = entry.value..sort(_byTime);
    if (!chain.any((t) => t.balance != null)) {
      unverifiable.add(entry.key);
      continue;
    }
    checked += chain.length;
    banks.add(_walk(entry.key, chain));
  }

  banks.sort((a, b) => b.gaps.length.compareTo(a.gaps.length));
  unverifiable.sort();
  return LedgerAudit(
    banks: banks,
    unverifiable: unverifiable,
    checked: checked,
  );
}

/// Đi dọc một chuỗi đã sắp xếp, dừng lại ở mỗi giao dịch có số dư để đối chiếu.
///
/// Giao dịch không kèm số dư vẫn được cộng vào [drift] — chúng đã được ghi
/// đúng, chỉ là ngân hàng không nói số dư sau đó. Bỏ qua chúng thì mọi mắt
/// xích phía sau đều báo lệch oan.
BankLedger _walk(String bankName, List<Txn> chain) {
  final gaps = <LedgerGap>[];
  Txn? anchor;
  var drift = 0;
  var links = 0;

  for (final txn in chain) {
    if (anchor == null) {
      // Chưa có mốc nào thì giao dịch có số dư đầu tiên trở thành mốc; mọi thứ
      // trước nó không đối chiếu được vì không biết bắt đầu từ đâu.
      if (txn.balance != null) anchor = txn;
      continue;
    }
    drift += txn.signedAmount;
    if (txn.balance == null) continue;

    links++;
    final expected = anchor.balance! + drift;
    if (txn.balance != expected) {
      gaps.add(
        LedgerGap(
          bankName: bankName,
          before: anchor,
          after: txn,
          expected: expected,
        ),
      );
    }
    anchor = txn;
    drift = 0;
  }

  return BankLedger(
    bankName: bankName,
    links: links,
    gaps: gaps,
    latestBalance: anchor?.balance,
  );
}

/// Cũ đến mới. Hai giao dịch cùng mốc thời gian thì xếp theo thứ tự đã ghi vào
/// sổ — thông báo bắn cùng một giây là chuyện thường, và thứ tự nào cũng phải
/// cố định thì kết quả đối soát mới lặp lại được.
int _byTime(Txn a, Txn b) {
  final byTime = a.postTime.compareTo(b.postTime);
  if (byTime != 0) return byTime;
  return (a.id ?? 0).compareTo(b.id ?? 0);
}
