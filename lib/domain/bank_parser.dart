import '../core/text.dart';
import '../models/models.dart';

/// Kết quả bóc tách một notification ngân hàng.
class ParseResult {
  ParseResult({
    required this.amount,
    required this.direction,
    required this.directionConfident,
    this.balance,
    this.description,
  });

  final int amount;
  final TxnDirection direction;

  /// `false` khi hướng tiền chỉ là phỏng đoán (không có dấu +/- rõ ràng
  /// và cũng không khớp từ khoá nào) — UI sẽ đánh dấu để user xác nhận.
  final bool directionConfident;
  final int? balance;
  final String? description;
}

/// Bóc tách nội dung notification của app ngân hàng / ví điện tử Việt Nam.
///
/// Mặc định không hard-code theo từng ngân hàng: mỗi nhà băng một format riêng
/// và họ đổi format bất chợt. Thay vào đó dựa trên các thành phần luôn xuất
/// hiện — con số kèm đơn vị tiền, dấu +/-, nhãn "SD"/"số dư", nhãn "ND".
///
/// Khi cách chung không đọc nổi một nhà băng nào đó, user khai [ParserProfile]
/// riêng cho app đó (màn "Ngân hàng") và mẫu riêng sẽ đè lên phần mặc định.
class BankParser {
  /// Con số có thể có dấu ngăn nghìn: "1.234.567", "1,234,567", "1234567".
  static const String _number = r'\d{1,3}(?:[.,]\d{3})+|\d+';

  /// Số tiền kèm đơn vị: "1.234.567 VND", "50,000đ", "100000 d", "12.000 đồng".
  ///
  /// The unit must not be followed by another letter or digit, or the bare "đ"
  /// swallows the first letter of a Vietnamese word and any number in front of
  /// it becomes an amount: "3 đơn hàng mới" read as 3 đồng, "2 đường Nguyễn
  /// Trãi" as 2 đồng. Excluding `[a-zA-Z0-9]` was not enough — "ơ" and "ư" are
  /// not ASCII, so exactly the words that start "đ" + diacritic slipped through.
  static final RegExp _defaultAmountRe = _compile(
    r'(?<sign>[+\-])?\s*(?<num>' +
        _number +
        r')\s*(?:vnđ|vnd|đồng|đ|d)(?![\p{L}\p{N}])',
  )!;

  /// Số dư sau giao dịch: "SD: 1,234,567VND", "Số dư: 1.234.567".
  static final RegExp _defaultBalanceRe = _compile(
    r'(?:s[ốo]\s*d[ưu]|sd|available\s*balance|balance)\s*[:=\-]?\s*(?<num>' +
        _number +
        r')',
  )!;

  /// Nội dung chuyển khoản: "ND: luong thang 7", "Nội dung: ...".
  /// Giá trị dừng ở cuối dòng hoặc ở dấu "|" — nhiều bank nhồi nhiều trường
  /// vào một dòng, và nhãn ND không phải lúc nào cũng nằm cuối thông báo.
  static final RegExp _defaultDescRe = _compile(
    r'(?:n[ộo]i\s*dung|nd|di[ễe]n\s*gi[ảa]i|content|memo)\s*[:=\-]\s*([^\n|]+)',
  )!;

  /// Từ khoá cho biết tiền vào tài khoản (đã bỏ dấu, chữ thường).
  static const List<String> defaultIncomeHints = [
    'ghi co',
    'nhan duoc',
    'nhan tien',
    'tien vao',
    'cong tien',
    'chuyen den',
    'ck den',
    'nap tien',
    'nap thanh cong',
    'hoan tien',
    'da nhan',
    'credited',
    'received',
  ];

  /// Từ khoá cho biết tiền ra khỏi tài khoản.
  static const List<String> defaultExpenseHints = [
    'ghi no',
    'thanh toan',
    'chi tieu',
    'tru tien',
    'chuyen tien',
    'chuyen khoan di',
    'ck di',
    'rut tien',
    'tien ra',
    'da chi',
    'mua hang',
    'thanh cong so tien',
    'debited',
    'payment',
    'purchase',
  ];

  /// Trả về `null` nếu notification không phải giao dịch: không tìm ra số tiền,
  /// tìm ra số tiền nhưng không biết tiền vào hay ra, hoặc bị bộ lọc của
  /// [profile] loại ra.
  static ParseResult? parse(
    String title,
    String content, {
    ParserProfile? profile,
  }) {
    final text = _preprocess('$title\n$content');
    if (text.trim().isEmpty) return null;

    final flat = flatten(text);
    if (profile != null && !_passesFilters(flat, profile)) return null;

    // Tìm số dư trước để loại con số đó ra khỏi ứng viên "số tiền giao dịch".
    final balanceMatch = _balanceRegex(profile).firstMatch(text);
    final balance = balanceMatch == null ? null : _numberIn(balanceMatch);

    final amountRe = _amountRegex(profile);
    RegExpMatch? amountMatch;
    for (final m in amountRe.allMatches(text)) {
      final overlapsBalance =
          balanceMatch != null &&
          m.start < balanceMatch.end &&
          m.end > balanceMatch.start;
      if (overlapsBalance) continue;
      if (_numberIn(m) == null) continue;
      amountMatch = m;
      break;
    }
    if (amountMatch == null) return null;

    final amount = _numberIn(amountMatch);
    if (amount == null || amount <= 0) return null;

    // No clue about which way the money went means this is not a transaction:
    // a number with a currency unit on it says nothing by itself. Promos, codes
    // and any message quoting a price all clear the amount step above.
    final resolved = _resolveDirection(
      text: text,
      flat: flat,
      amountMatch: amountMatch,
      profile: profile,
    );
    if (resolved == null) return null;
    final (direction, confident) = resolved;

    return ParseResult(
      amount: amount,
      direction: direction,
      directionConfident: confident,
      balance: balance,
      description: _description(text, title, content, profile),
    );
  }

  // ------------------------------------------------------------ mẫu riêng

  /// Regex user tự viết. Regex hỏng thì coi như không khai — thà bóc tách theo
  /// cách mặc định còn hơn ném lỗi giữa luồng nhận notification.
  static RegExp? _compile(String pattern) {
    if (pattern.trim().isEmpty) return null;
    try {
      return RegExp(
        pattern,
        caseSensitive: false,
        unicode: true,
        multiLine: true,
      );
    } on FormatException {
      return null;
    }
  }

  /// Regex đúng hay hỏng — màn cấu hình dùng để báo đỏ ngay lúc user gõ.
  static bool isValidPattern(String pattern) =>
      pattern.trim().isEmpty || _compile(pattern) != null;

  /// Nhãn user gõ ("Số tiền giao dịch") thành đoạn regex đứng trước giá trị.
  /// Khoảng trắng trong nhãn khớp lỏng để không phụ thuộc cách gõ.
  static String _labelPrefix(String label) {
    final escaped = RegExp.escape(label.trim());
    return '${escaped.replaceAll(RegExp(r'\\?\s+'), r'\s*')}\\s*[:=\\-]?\\s*';
  }

  static RegExp _amountRegex(ParserProfile? profile) {
    final custom = _compile(profile?.amountPattern ?? '');
    if (custom != null) return custom;
    final label = profile?.amountLabel.trim() ?? '';
    if (label.isEmpty) return _defaultAmountRe;
    return _compile(
          '${_labelPrefix(label)}(?<sign>[+\\-])?\\s*(?<num>$_number)',
        ) ??
        _defaultAmountRe;
  }

  static RegExp _balanceRegex(ParserProfile? profile) {
    final custom = _compile(profile?.balancePattern ?? '');
    if (custom != null) return custom;
    final label = profile?.balanceLabel.trim() ?? '';
    if (label.isEmpty) return _defaultBalanceRe;
    return _compile('${_labelPrefix(label)}(?<num>$_number)') ??
        _defaultBalanceRe;
  }

  static RegExp _descRegex(ParserProfile? profile) {
    final custom = _compile(profile?.descPattern ?? '');
    if (custom != null) return custom;
    final label = profile?.descLabel.trim() ?? '';
    if (label.isEmpty) return _defaultDescRe;
    return _compile('${_labelPrefix(label)}([^\\n|]+)') ?? _defaultDescRe;
  }

  static bool _passesFilters(String flat, ParserProfile profile) {
    if (profile.onlyIf.isNotEmpty &&
        !profile.onlyIf.any((k) => flat.contains(flatten(k)))) {
      return false;
    }
    return !profile.ignoreIf.any((k) => flat.contains(flatten(k)));
  }

  // ------------------------------------------------------------ đọc giá trị

  /// Con số trong một match: ưu tiên nhóm tên `num`, rồi nhóm 1, rồi cả match.
  /// Nhờ vậy regex user viết kiểu nào cũng dùng được.
  static int? _numberIn(RegExpMatch match) {
    final raw =
        _namedGroup(match, 'num') ??
        (match.groupCount >= 1 ? match.group(1) : null) ??
        match.group(0);
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  /// `namedGroup` ném lỗi khi regex không có nhóm tên đó — user viết regex
  /// không có `num`/`sign` là chuyện thường.
  static String? _namedGroup(RegExpMatch match, String name) {
    try {
      return match.namedGroup(name);
    } on ArgumentError {
      return null;
    }
  }

  /// The direction and how sure we are of it, or `null` when the notification
  /// never says whether money came in or went out — [parse] treats that as not
  /// a transaction at all.
  ///
  /// Evidence that contradicts itself (keywords for both directions match) is
  /// still evidence: money clearly moved, only the direction is unclear, so it
  /// comes back with `false` for the UI to ask about. That is a different thing
  /// from having no evidence whatsoever.
  static (TxnDirection, bool)? _resolveDirection({
    required String text,
    required String flat,
    required RegExpMatch amountMatch,
    required ParserProfile? profile,
  }) {
    switch (profile?.directionMode ?? DirectionMode.auto) {
      case DirectionMode.alwaysIncome:
        return (TxnDirection.income, true);
      case DirectionMode.alwaysExpense:
        return (TxnDirection.expense, true);
      case DirectionMode.auto:
        break;
    }

    final sign = _signOf(text, amountMatch);
    if (sign == '+') return (TxnDirection.income, true);
    if (sign == '-') return (TxnDirection.expense, true);

    // Từ khoá user tự khai xét trước và thắng luôn. Từ khoá của user thường
    // chứa sẵn một từ mặc định của phía ngược lại — khai "nhan thanh toan" là
    // thu thì bên trong đã có "thanh toan" của phía chi. Trộn chung một rổ thì
    // chính cái user vừa khai lại làm kết quả hoá mơ hồ.
    final userIncomeAt = _firstHitIndex(flat, [
      ...?profile?.incomeHints.map(flatten),
    ]);
    final userExpenseAt = _firstHitIndex(flat, [
      ...?profile?.expenseHints.map(flatten),
    ]);
    if (userIncomeAt >= 0 || userExpenseAt >= 0) {
      if (userExpenseAt < 0) return (TxnDirection.income, true);
      if (userIncomeAt < 0) return (TxnDirection.expense, true);
      // User khai cả hai phía cùng khớp — không đoán hộ, cắm cờ để user xem lại.
      return (
        userIncomeAt < userExpenseAt
            ? TxnDirection.income
            : TxnDirection.expense,
        false,
      );
    }

    final incomeAt = _firstHitIndex(flat, defaultIncomeHints);
    final expenseAt = _firstHitIndex(flat, defaultExpenseHints);
    if (incomeAt < 0 && expenseAt < 0) {
      // No sign, no keyword — drop it, so [parse] returns `null`. This used to
      // guess expense and raise the review flag, which turned every message
      // carrying a number and a "đ" into a spend the user had to go and delete.
      // A real bank whose format has neither can be handled by setting
      // `directionMode` on that app's parser profile.
      return null;
    }
    if (incomeAt < 0) return (TxnDirection.expense, true);
    if (expenseAt < 0) return (TxnDirection.income, true);
    // Cả hai cùng xuất hiện — từ khoá nào đứng trước thì thắng.
    return (
      incomeAt < expenseAt ? TxnDirection.income : TxnDirection.expense,
      false,
    );
  }

  /// Dấu +/- của số tiền: lấy từ nhóm `sign` nếu regex có khai, không thì nhìn
  /// ký tự ngay trước con số (regex user viết thường không bắt dấu).
  static String? _signOf(String text, RegExpMatch match) {
    final named = _namedGroup(match, 'sign');
    if (named != null && named.isNotEmpty) return named;

    final matched = match.group(0) ?? '';
    final inside = RegExp(r'[+\-](?=\s*\d)').firstMatch(matched);
    if (inside != null) return inside.group(0);

    for (var i = match.start - 1; i >= 0; i--) {
      final ch = text[i];
      if (ch == ' ') continue;
      if (ch == '+' || ch == '-') return ch;
      return null;
    }
    return null;
  }

  static String? _description(
    String text,
    String title,
    String content,
    ParserProfile? profile,
  ) {
    final match = _descRegex(profile).firstMatch(text);
    var description = (match == null
        ? null
        : (match.groupCount >= 1 ? match.group(1) : match.group(0)))
        ?.trim();
    if (description != null) {
      // Nhiều bank ngăn các trường bằng "|", cắt phần thừa phía sau.
      description = description.split('|').first.trim();
      if (description.isEmpty) description = null;
    }
    return description ?? _fallbackDescription(title, content);
  }

  /// Chuẩn hoá vài biến thể ký hiệu trước khi đưa vào regex.
  static String _preprocess(String raw) => raw
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'\(\s*\+\s*\)'), '+') // ACB: (+)500,000
      .replaceAll(RegExp(r'\(\s*-\s*\)'), '-')
      .replaceAll(RegExp(r'[ \t]+'), ' ');

  /// Khi không có nhãn "ND", lấy tạm dòng nội dung làm mô tả.
  static String? _fallbackDescription(String title, String content) {
    final line = content.trim().isNotEmpty ? content.trim() : title.trim();
    if (line.isEmpty) return null;
    return line.length > 140 ? '${line.substring(0, 140)}…' : line;
  }

  static int _firstHitIndex(String haystack, List<String> needles) {
    var best = -1;
    for (final n in needles) {
      final i = haystack.indexOf(n);
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }
}
