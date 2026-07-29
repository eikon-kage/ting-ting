/// Cách quyết định thu hay chi cho một nguồn.
enum DirectionMode {
  /// Nhìn dấu +/- trước số tiền, không có thì dò từ khoá.
  auto,

  /// Thông báo của nguồn này luôn là tiền vào (ví dụ app chỉ báo nhận tiền).
  alwaysIncome,

  /// Luôn là tiền ra.
  alwaysExpense,
}

extension DirectionModeX on DirectionMode {
  String get code => name;

  String get label => switch (this) {
    DirectionMode.auto => 'Tự động',
    DirectionMode.alwaysIncome => 'Luôn là thu',
    DirectionMode.alwaysExpense => 'Luôn là chi',
  };

  static DirectionMode fromCode(String? code) {
    for (final mode in DirectionMode.values) {
      if (mode.name == code) return mode;
    }
    return DirectionMode.auto;
  }
}

/// Mẫu bóc tách riêng cho một app ngân hàng.
///
/// Parser mặc định đọc được phần lớn thông báo, nhưng mỗi nhà băng một kiểu và
/// họ đổi format bất chợt. Khi kiểu nào đó không đọc ra, user tự khai ở đây:
/// nhãn đứng trước từng giá trị (dễ nhất) hoặc regex (khi nhãn không đủ).
///
/// Trường nào để trống thì phần đó vẫn chạy theo cách mặc định — không cần
/// khai đủ mọi thứ mới dùng được.
class ParserProfile {
  const ParserProfile({
    required this.packageName,
    this.amountLabel = '',
    this.amountPattern = '',
    this.balanceLabel = '',
    this.balancePattern = '',
    this.descLabel = '',
    this.descPattern = '',
    this.directionMode = DirectionMode.auto,
    this.incomeHints = const [],
    this.expenseHints = const [],
    this.onlyIf = const [],
    this.ignoreIf = const [],
    this.sampleTitle = '',
    this.sampleContent = '',
  });

  factory ParserProfile.fromMap(Map<String, Object?> map) => ParserProfile(
    packageName: map['package_name'] as String,
    amountLabel: map['amount_label'] as String? ?? '',
    amountPattern: map['amount_pattern'] as String? ?? '',
    balanceLabel: map['balance_label'] as String? ?? '',
    balancePattern: map['balance_pattern'] as String? ?? '',
    descLabel: map['desc_label'] as String? ?? '',
    descPattern: map['desc_pattern'] as String? ?? '',
    directionMode: DirectionModeX.fromCode(map['direction_mode'] as String?),
    incomeHints: splitList(map['income_hints'] as String?),
    expenseHints: splitList(map['expense_hints'] as String?),
    onlyIf: splitList(map['only_if'] as String?),
    ignoreIf: splitList(map['ignore_if'] as String?),
    sampleTitle: map['sample_title'] as String? ?? '',
    sampleContent: map['sample_content'] as String? ?? '',
  );

  final String packageName;

  /// Nhãn đứng ngay trước số tiền, ví dụ "Số tiền giao dịch".
  final String amountLabel;

  /// Regex tự viết cho số tiền — ưu tiên hơn [amountLabel]. Nhóm `num` (hoặc
  /// nhóm 1) là con số, nhóm `sign` nếu có là dấu +/-.
  final String amountPattern;

  final String balanceLabel;
  final String balancePattern;
  final String descLabel;
  final String descPattern;

  final DirectionMode directionMode;

  /// Từ khoá bổ sung cho hướng tiền, cộng thêm vào danh sách mặc định.
  final List<String> incomeHints;
  final List<String> expenseHints;

  /// Chỉ coi là giao dịch khi thông báo chứa một trong các từ này (rỗng = bỏ
  /// qua điều kiện). Dùng để chặn thông báo quảng cáo có kèm số tiền.
  final List<String> onlyIf;

  /// Bỏ qua thông báo chứa một trong các từ này.
  final List<String> ignoreIf;

  /// Thông báo mẫu user chọn để thử mẫu bóc tách, lưu lại cho lần sau.
  final String sampleTitle;
  final String sampleContent;

  /// `true` khi user chưa khai gì — dùng y hệt parser mặc định.
  bool get isDefault =>
      amountLabel.isEmpty &&
      amountPattern.isEmpty &&
      balanceLabel.isEmpty &&
      balancePattern.isEmpty &&
      descLabel.isEmpty &&
      descPattern.isEmpty &&
      directionMode == DirectionMode.auto &&
      incomeHints.isEmpty &&
      expenseHints.isEmpty &&
      onlyIf.isEmpty &&
      ignoreIf.isEmpty;

  ParserProfile copyWith({
    String? amountLabel,
    String? amountPattern,
    String? balanceLabel,
    String? balancePattern,
    String? descLabel,
    String? descPattern,
    DirectionMode? directionMode,
    List<String>? incomeHints,
    List<String>? expenseHints,
    List<String>? onlyIf,
    List<String>? ignoreIf,
    String? sampleTitle,
    String? sampleContent,
  }) => ParserProfile(
    packageName: packageName,
    amountLabel: amountLabel ?? this.amountLabel,
    amountPattern: amountPattern ?? this.amountPattern,
    balanceLabel: balanceLabel ?? this.balanceLabel,
    balancePattern: balancePattern ?? this.balancePattern,
    descLabel: descLabel ?? this.descLabel,
    descPattern: descPattern ?? this.descPattern,
    directionMode: directionMode ?? this.directionMode,
    incomeHints: incomeHints ?? this.incomeHints,
    expenseHints: expenseHints ?? this.expenseHints,
    onlyIf: onlyIf ?? this.onlyIf,
    ignoreIf: ignoreIf ?? this.ignoreIf,
    sampleTitle: sampleTitle ?? this.sampleTitle,
    sampleContent: sampleContent ?? this.sampleContent,
  );

  Map<String, Object?> toMap() => {
    'package_name': packageName,
    'amount_label': amountLabel,
    'amount_pattern': amountPattern,
    'balance_label': balanceLabel,
    'balance_pattern': balancePattern,
    'desc_label': descLabel,
    'desc_pattern': descPattern,
    'direction_mode': directionMode.code,
    'income_hints': joinList(incomeHints),
    'expense_hints': joinList(expenseHints),
    'only_if': joinList(onlyIf),
    'ignore_if': joinList(ignoreIf),
    'sample_title': sampleTitle,
    'sample_content': sampleContent,
  };

  /// Danh sách từ khoá user gõ: ngăn nhau bằng dấu phẩy hoặc xuống dòng.
  static List<String> splitList(String? raw) => (raw ?? '')
      .split(RegExp(r'[,\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static String joinList(List<String> items) => items.join(', ');
}
