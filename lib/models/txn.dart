import 'category.dart';

/// Tiền nằm ở đâu. Dòng tiền được theo dõi tách làm hai ví.
enum AccountKind {
  /// Tài khoản ngân hàng / ví điện tử — số liệu tự lấy từ thông báo.
  bank,

  /// Tiền mặt trong người — chỉ có được khi user tự nhập hoặc rút từ ATM.
  cash,
}

extension AccountKindX on AccountKind {
  String get code => name;

  String get label => this == AccountKind.bank ? 'Tài khoản' : 'Tiền mặt';

  static AccountKind fromCode(String? code) =>
      code == AccountKind.cash.name ? AccountKind.cash : AccountKind.bank;
}

/// Vai trò của một giao dịch trong sổ nợ.
///
/// Bốn loại này không được tính vào Thu–Chi: cho bố mẹ vay không phải là tiêu
/// tiền, bố mẹ chuyển tiền cho mình cũng không phải thu nhập. Chúng chỉ làm
/// thay đổi số dư nợ giữa mình và người đó.
enum DebtType {
  /// Mình đưa tiền cho người khác, họ sẽ trả lại.
  lend,

  /// Mình nhận tiền của người khác, sau này phải trả.
  borrow,

  /// Người ta trả nợ cho mình (tiền vào).
  collect,

  /// Mình trả nợ cho người ta (tiền ra).
  repay,
}

extension DebtTypeX on DebtType {
  String get code => name;

  String get label => switch (this) {
    DebtType.lend => 'Cho vay',
    DebtType.borrow => 'Đi vay',
    DebtType.collect => 'Thu nợ',
    DebtType.repay => 'Trả nợ',
  };

  /// Giải thích ngắn cho user khi chọn loại nợ.
  String get hint => switch (this) {
    DebtType.lend => 'Mình đưa tiền, họ sẽ trả lại',
    DebtType.borrow => 'Mình nhận tiền, sau này phải trả',
    DebtType.collect => 'Họ trả nợ cho mình',
    DebtType.repay => 'Mình trả nợ cho họ',
  };

  /// Tiền chạy hướng nào khi ghi khoản nợ này — cho vay và trả nợ là tiền ra,
  /// đi vay và thu nợ là tiền vào.
  TxnDirection get direction => switch (this) {
    DebtType.lend || DebtType.repay => TxnDirection.expense,
    DebtType.borrow || DebtType.collect => TxnDirection.income,
  };

  /// Ảnh hưởng lên số dư: dương nghĩa là người đó nợ mình thêm.
  int signFor(int amount) => switch (this) {
    DebtType.lend => amount,
    DebtType.collect => -amount,
    DebtType.borrow => -amount,
    DebtType.repay => amount,
  };

  static DebtType? fromCode(String? code) {
    if (code == null) return null;
    for (final type in DebtType.values) {
      if (type.name == code) return type;
    }
    return null;
  }
}

/// Hướng tiền: vào tài khoản (thu) hoặc ra khỏi tài khoản (chi).
enum TxnDirection { income, expense }

extension TxnDirectionX on TxnDirection {
  String get code => this == TxnDirection.income ? 'in' : 'out';
  String get label => this == TxnDirection.income ? 'Thu' : 'Chi';

  static TxnDirection fromCode(String code) =>
      code == 'in' ? TxnDirection.income : TxnDirection.expense;
}

/// Một giao dịch đã được bóc tách từ notification của app ngân hàng.
class Txn {
  Txn({
    this.id,
    required this.packageName,
    required this.bankName,
    required this.direction,
    required this.amount,
    this.balance,
    this.description,
    required this.category,
    required this.rawTitle,
    required this.rawContent,
    required this.postTime,
    this.needsReview = false,
    this.note,
    this.excluded = false,
    this.fingerprintOverride,
    this.debtType,
    this.person,
    this.accountKind = AccountKind.bank,
    this.isTransfer = false,
  });

  /// Giao dịch do user tự nhập (tiền mặt) — không đến từ notification nào.
  static const String manualPackage = '__manual__';

  factory Txn.fromMap(Map<String, Object?> map) => Txn(
    id: map['id'] as int?,
    packageName: map['package_name'] as String,
    bankName: map['bank_name'] as String,
    direction: TxnDirectionX.fromCode(map['direction'] as String),
    amount: map['amount'] as int,
    balance: map['balance'] as int?,
    description: map['description'] as String?,
    category: map['category'] as String,
    rawTitle: map['raw_title'] as String? ?? '',
    rawContent: map['raw_content'] as String? ?? '',
    postTime: DateTime.fromMillisecondsSinceEpoch(map['post_time'] as int),
    needsReview: (map['needs_review'] as int? ?? 0) == 1,
    note: map['note'] as String?,
    excluded: (map['excluded'] as int? ?? 0) == 1,
    // Giữ nguyên khoá đã lưu để lần cập nhật sau không sinh ra khoá khác.
    fingerprintOverride: map['fingerprint'] as String?,
    debtType: DebtTypeX.fromCode(map['debt_type'] as String?),
    person: map['person'] as String?,
    accountKind: AccountKindX.fromCode(map['account_kind'] as String?),
    isTransfer: (map['is_transfer'] as int? ?? 0) == 1,
  );

  final int? id;
  final String packageName;
  final String bankName;
  final TxnDirection direction;

  /// Số tiền, đơn vị đồng (không có phần thập phân).
  final int amount;

  /// Số dư sau giao dịch nếu notification có kèm.
  final int? balance;
  final String? description;
  final String category;
  final String rawTitle;
  final String rawContent;
  final DateTime postTime;

  /// `true` khi parser không chắc chắn hướng tiền — cần user xác nhận lại.
  final bool needsReview;

  /// Ghi chú user tự thêm.
  final String? note;

  /// Không tính vào báo cáo. Dùng cho chuyển tiền giữa các tài khoản của
  /// chính mình — nếu tính thì vừa thành một khoản thu vừa thành một khoản chi.
  final bool excluded;

  /// Khác `null` thì đây là giao dịch nợ, không tính vào Thu–Chi.
  final DebtType? debtType;

  /// Tên người liên quan tới khoản nợ. `null` khi user đã bấm nhanh
  /// "cho vay" từ notification nhưng chưa kịp gán tên.
  final String? person;

  /// Ví mà giao dịch này làm thay đổi.
  final AccountKind accountKind;

  /// Chuyển tiền giữa hai ví của chính mình — rút ATM, nộp tiền vào tài khoản.
  /// Tiền không mất đi nên không tính là thu hay chi, chỉ đổi chỗ:
  /// rút ATM là `direction = expense`, `accountKind = bank` -> tiền mặt tăng.
  final bool isTransfer;

  bool get isManual => packageName == manualPackage;

  bool get isDebt => debtType != null;

  /// Giao dịch nợ đã phân loại nhưng chưa biết là nợ với ai.
  bool get needsPerson => isDebt && (person == null || person!.isEmpty);

  /// Chỉ những giao dịch này mới được cộng vào báo cáo Thu–Chi.
  bool get countsInReport => !excluded && debtType == null && !isTransfer;

  /// Kiểu tiền vào, `null` với khoản chi.
  ///
  /// Suy ra từ nhóm chi tiêu chứ không phải một cột riêng: gán nhóm "Chia bill"
  /// là user đã nói xong đây là tiền người ta trả lại, không phải chọn thêm.
  IncomeKind? get incomeKind => direction == TxnDirection.income
      ? IncomeKindX.fromCategory(category)
      : null;

  /// Dấu của giao dịch trong một tổng: thu là cộng, chi là trừ.
  int get signedAmount =>
      direction == TxnDirection.income ? amount : -amount;

  /// Ảnh hưởng lên số dư nợ với [person]. Dương = họ nợ mình thêm.
  int get debtEffect => debtType?.signFor(amount) ?? 0;

  /// Ví nhận tiền ở đầu bên kia của một giao dịch chuyển ví.
  AccountKind get transferCounterpart =>
      accountKind == AccountKind.bank ? AccountKind.cash : AccountKind.bank;

  /// Chỉ dùng cho giao dịch nhập tay, xem [fingerprint].
  final String? fingerprintOverride;

  /// Khoá chống trùng: cùng nội dung trong cùng một phút coi như một giao dịch.
  /// Android hay bắn lại notification khi nó được cập nhật.
  ///
  /// Giao dịch nhập tay thì không áp dụng — user có quyền ghi hai khoản giống
  /// hệt nhau — nên mỗi bản ghi nhận một khoá riêng.
  String get fingerprint =>
      fingerprintOverride ??
      '$packageName|$rawTitle|$rawContent|${postTime.millisecondsSinceEpoch ~/ 60000}';

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'package_name': packageName,
    'bank_name': bankName,
    'direction': direction.code,
    'amount': amount,
    'balance': balance,
    'description': description,
    'category': category,
    'raw_title': rawTitle,
    'raw_content': rawContent,
    'post_time': postTime.millisecondsSinceEpoch,
    'needs_review': needsReview ? 1 : 0,
    'note': note,
    'excluded': excluded ? 1 : 0,
    'debt_type': debtType?.code,
    'person': person,
    'account_kind': accountKind.code,
    'is_transfer': isTransfer ? 1 : 0,
    'fingerprint': fingerprint,
  };

  /// Truyền `clearDebt: true` để gỡ giao dịch khỏi sổ nợ (đưa về Thu–Chi).
  Txn copyWith({
    TxnDirection? direction,
    String? category,
    bool? needsReview,
    String? note,
    bool? excluded,
    DebtType? debtType,
    String? person,
    bool clearDebt = false,
    AccountKind? accountKind,
    bool? isTransfer,
  }) => Txn(
    id: id,
    packageName: packageName,
    bankName: bankName,
    direction: direction ?? this.direction,
    amount: amount,
    balance: balance,
    description: description,
    category: category ?? this.category,
    rawTitle: rawTitle,
    rawContent: rawContent,
    postTime: postTime,
    needsReview: needsReview ?? this.needsReview,
    note: note ?? this.note,
    excluded: excluded ?? this.excluded,
    fingerprintOverride: fingerprintOverride,
    debtType: clearDebt ? null : (debtType ?? this.debtType),
    person: clearDebt ? null : (person ?? this.person),
    accountKind: accountKind ?? this.accountKind,
    isTransfer: isTransfer ?? this.isTransfer,
  );
}
