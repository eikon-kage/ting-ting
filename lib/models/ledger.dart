import 'txn.dart';

/// Một chỗ hở trong chuỗi số dư của một ngân hàng.
///
/// Hai giao dịch liền nhau đều kèm số dư thì số dư sau phải bằng số dư trước
/// cộng mọi khoản đã ghi ở giữa. Không bằng nghĩa là có giao dịch thật đã xảy
/// ra mà app không thấy — thông báo bị Android nuốt, máy tắt, hoặc nội dung bị
/// giấu. Phần chênh chính là số tiền còn thiếu.
class LedgerGap {
  const LedgerGap({
    required this.bankName,
    required this.before,
    required this.after,
    required this.expected,
  });

  final String bankName;

  /// Giao dịch có số dư ngay trước chỗ hở.
  final Txn before;

  /// Giao dịch có số dư ngay sau chỗ hở — chính nó làm lộ ra chênh lệch.
  final Txn after;

  /// Số dư lẽ ra phải có ở [after] nếu không thiếu giao dịch nào.
  final int expected;

  /// Số dư ngân hàng thật sự báo.
  int get actual => after.balance ?? expected;

  /// Phần chênh, có dấu. Dương = có tiền vào chưa ghi, âm = có tiền ra chưa ghi.
  int get missing => actual - expected;

  int get amount => missing.abs();

  /// Hướng của giao dịch còn thiếu.
  TxnDirection get direction =>
      missing > 0 ? TxnDirection.income : TxnDirection.expense;

  /// Giao dịch thiếu nằm đâu đó trong khoảng `(from, to]`.
  DateTime get from => before.postTime;
  DateTime get to => after.postTime;
}

/// Kết quả đối soát của một ngân hàng.
class BankLedger {
  const BankLedger({
    required this.bankName,
    required this.links,
    required this.gaps,
    required this.latestBalance,
  });

  final String bankName;

  /// Số mắt xích đã đối chiếu được (mỗi cặp số dư liền nhau là một mắt xích).
  final int links;

  final List<LedgerGap> gaps;

  /// Số dư mới nhất ngân hàng báo, `null` khi chưa có giao dịch nào kèm số dư.
  final int? latestBalance;

  bool get isClean => gaps.isEmpty;

  /// Tổng tiền vào chưa ghi.
  int get missingIn =>
      gaps.where((g) => g.missing > 0).fold(0, (sum, g) => sum + g.missing);

  /// Tổng tiền ra chưa ghi, trả về số dương.
  int get missingOut =>
      gaps.where((g) => g.missing < 0).fold(0, (sum, g) => sum - g.missing);

  /// Quá nửa số mắt xích lệch thì chuỗi này không đáng tin: gần như chắc chắn
  /// hai tài khoản khác nhau đang dùng chung một tên ngân hàng, nên số dư của
  /// chúng xen kẽ nhau chứ không nối tiếp. Báo từng chỗ hở lúc này chỉ gây
  /// nhiễu, UI nên nói thẳng nguyên nhân.
  bool get unreliable => links >= 4 && gaps.length * 2 > links;
}

/// Toàn cảnh một lần kiểm sổ.
class LedgerAudit {
  const LedgerAudit({
    required this.banks,
    required this.unverifiable,
    required this.checked,
  });

  static const empty = LedgerAudit(banks: [], unverifiable: [], checked: 0);

  /// Các ngân hàng đối soát được, ngân hàng nhiều chỗ hở nhất đứng trước.
  final List<BankLedger> banks;

  /// Ngân hàng chưa từng gửi số dư trong thông báo — không có gì để đối chiếu.
  /// Không phải lỗi, chỉ là vùng mù cần nói cho user biết.
  final List<String> unverifiable;

  /// Số giao dịch đã đưa vào đối soát.
  final int checked;

  List<BankLedger> get suspicious =>
      banks.where((b) => !b.isClean && !b.unreliable).toList();

  List<BankLedger> get unreliable => banks.where((b) => b.unreliable).toList();

  List<LedgerGap> get gaps => [
    for (final bank in suspicious) ...bank.gaps,
  ];

  int get gapCount => gaps.length;

  /// Tổng chênh lệch ròng của những chỗ hở đáng tin.
  int get netMissing => gaps.fold(0, (sum, g) => sum + g.missing);

  /// Không có gì để nói: chưa đủ dữ liệu đối soát.
  bool get hasNothingToCheck => banks.isEmpty && unverifiable.isEmpty;

  /// Mọi ngân hàng đối soát được đều khớp.
  bool get isClean => banks.isNotEmpty && banks.every((b) => b.isClean);
}
