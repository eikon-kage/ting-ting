/// Cách chia một mục cho những người cùng gánh.
enum BillSplitMode {
  /// Ai có tên trong mục thì gánh bằng nhau.
  equal,

  /// Mỗi người một con số riêng — ai gọi món đắt thì trả nhiều.
  custom,
}

extension BillSplitModeX on BillSplitMode {
  String get code => name;

  String get label =>
      this == BillSplitMode.equal ? 'Chia đều' : 'Mỗi người một khoản';

  static BillSplitMode fromCode(String? code) =>
      code == BillSplitMode.custom.name
      ? BillSplitMode.custom
      : BillSplitMode.equal;
}

/// Phần của một người trong một mục.
class BillShare {
  const BillShare(this.person, [this.amount]);

  final String person;

  /// Chỉ có ở chế độ [BillSplitMode.custom]. Chia đều thì số tiền được tính
  /// ra lúc chốt sổ, không lưu sẵn — sửa số tiền của mục là phần ai nấy đổi
  /// theo, không phải đi sửa lại từng dòng.
  final int? amount;
}

/// Một cuộc chia tiền: chuyến đi chơi, bữa ăn chung, tiền nhà tháng này.
///
/// Bill đứng ngoài Thu–Chi lẫn Sổ nợ. Tiền thật đã ra khỏi ví ai thì thông báo
/// ngân hàng của người đó ghi rồi; ở đây chỉ tính xem cuối cùng ai phải đưa
/// cho ai bao nhiêu.
class Bill {
  const Bill({
    required this.key,
    required this.title,
    required this.members,
    required this.createdAt,
    this.settled = false,
  });

  /// Tên dành riêng cho chính chủ máy. Có mặt trong mọi bill và không xoá được
  /// — chốt sổ xong thì câu trả lời user cần là "mình phải đưa ai bao nhiêu".
  static const String me = 'Tôi';

  /// Bill mới, [others] là những người còn lại ngoài mình.
  factory Bill.create({
    required String title,
    required List<String> others,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return Bill(
      key: 'bill|${now.microsecondsSinceEpoch}',
      title: title.trim(),
      members: mergeMembers(const [me], others),
      createdAt: now,
    );
  }

  factory Bill.fromMap(Map<String, Object?> map) => Bill(
    key: map['key'] as String,
    title: map['title'] as String,
    members: decodeNames(map['members'] as String?),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    settled: (map['settled'] as int? ?? 0) == 1,
  );

  final String key;
  final String title;

  /// Mọi người trong cuộc, [me] luôn đứng đầu.
  final List<String> members;

  final DateTime createdAt;

  /// Đã đưa tiền cho nhau xong. Bill vẫn nằm lại để tra cứu.
  final bool settled;

  /// Những người khác ngoài mình.
  List<String> get others => [
    for (final member in members)
      if (member != me) member,
  ];

  Map<String, Object?> toMap() => {
    'key': key,
    'title': title,
    'members': encodeNames(members),
    'created_at': createdAt.millisecondsSinceEpoch,
    'settled': settled ? 1 : 0,
  };

  Bill copyWith({String? title, List<String>? members, bool? settled}) => Bill(
    key: key,
    title: title ?? this.title,
    members: members ?? this.members,
    createdAt: createdAt,
    settled: settled ?? this.settled,
  );

  /// Bỏ khoảng trắng thừa và hai ký tự dùng làm dấu phân cách lúc lưu — tên
  /// mang chúng theo thì đọc file ra sẽ tách nhầm.
  static String sanitizeName(String raw) => raw
      .replaceAll(RegExp(r'[=\n\r]'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Nối thêm người vào danh sách, bỏ tên rỗng và tên đã có (không phân biệt
  /// hoa thường) — thêm "Nam" hai lần thì phần chia đều sẽ lệch.
  static List<String> mergeMembers(
    List<String> current,
    Iterable<String> adding,
  ) {
    final result = [...current];
    for (final raw in adding) {
      final name = sanitizeName(raw);
      if (name.isEmpty) continue;
      final exists = result.any((m) => m.toLowerCase() == name.toLowerCase());
      if (!exists) result.add(name);
    }
    return result;
  }

  static String encodeNames(List<String> names) => names.join('\n');

  static List<String> decodeNames(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return [
      for (final line in raw.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }
}

/// Một khoản đã tiêu trong bill: ai trả, bao nhiêu, những ai cùng gánh.
class BillItem {
  const BillItem({
    required this.key,
    required this.billKey,
    required this.label,
    required this.amount,
    required this.payer,
    required this.mode,
    required this.shares,
    required this.createdAt,
  });

  factory BillItem.create({
    required String billKey,
    required String label,
    required int amount,
    required String payer,
    required BillSplitMode mode,
    required List<BillShare> shares,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return BillItem(
      key: 'item|${now.microsecondsSinceEpoch}',
      billKey: billKey,
      label: label.trim(),
      amount: amount,
      payer: payer,
      mode: mode,
      shares: shares,
      createdAt: now,
    );
  }

  factory BillItem.fromMap(Map<String, Object?> map) => BillItem(
    key: map['key'] as String,
    billKey: map['bill_key'] as String,
    label: map['label'] as String,
    amount: map['amount'] as int,
    payer: map['payer'] as String,
    mode: BillSplitModeX.fromCode(map['split_mode'] as String?),
    shares: decodeShares(map['shares'] as String?),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
  );

  final String key;
  final String billKey;

  /// "Ăn tối", "Xăng xe", "Phòng khách sạn"...
  final String label;

  final int amount;

  /// Người đã móc tiền ra trả cho cả nhóm.
  final String payer;

  final BillSplitMode mode;

  /// Những người cùng gánh mục này. Để trống nghĩa là cả nhóm cùng gánh.
  final List<BillShare> shares;

  final DateTime createdAt;

  List<String> get people => [for (final share in shares) share.person];

  /// Tổng số tiền đã gán cho từng người ở chế độ tuỳ chỉnh.
  int get assigned => shares.fold(0, (sum, share) => sum + (share.amount ?? 0));

  Map<String, Object?> toMap() => {
    'key': key,
    'bill_key': billKey,
    'label': label,
    'amount': amount,
    'payer': payer,
    'split_mode': mode.code,
    'shares': encodeShares(shares),
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  BillItem copyWith({
    String? label,
    int? amount,
    String? payer,
    BillSplitMode? mode,
    List<BillShare>? shares,
  }) => BillItem(
    key: key,
    billKey: billKey,
    label: label ?? this.label,
    amount: amount ?? this.amount,
    payer: payer ?? this.payer,
    mode: mode ?? this.mode,
    shares: shares ?? this.shares,
    createdAt: createdAt,
  );

  /// Mỗi dòng một người: "Nam" khi chia đều, "Nam=150000" khi mỗi người một số.
  static String encodeShares(List<BillShare> shares) => [
    for (final share in shares)
      share.amount == null ? share.person : '${share.person}=${share.amount}',
  ].join('\n');

  static List<BillShare> decodeShares(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final result = <BillShare>[];
    for (final line in raw.split('\n')) {
      if (line.trim().isEmpty) continue;
      final at = line.lastIndexOf('=');
      if (at < 0) {
        result.add(BillShare(line.trim()));
        continue;
      }
      result.add(
        BillShare(
          line.substring(0, at).trim(),
          int.tryParse(line.substring(at + 1).trim()),
        ),
      );
    }
    return result;
  }
}
