import '../core/text.dart';

/// Kết quả khi ghi một nhóm — UI tự dịch ra câu báo cho user.
enum CategorySaveResult { ok, nameEmpty, nameTaken }

/// Ba kiểu tiền vào. Cùng làm số dư tăng lên nhưng không cùng nghĩa: chỉ
/// [earned] là tiền mình kiếm được, hai kiểu còn lại là tiền của người khác
/// đang tạm nằm trong ví mình.
enum IncomeKind {
  /// Lương, thưởng, bán được cái gì — tiền thật sự kiếm ra.
  earned,

  /// Người cùng bill trả lại phần của họ. Không phải thu nhập mà là tiền bù
  /// cho khoản mình đã ứng ra trả cho cả nhóm.
  shareBill,

  /// Mình vay của người khác, sau này phải trả lại.
  borrowed,
}

extension IncomeKindX on IncomeKind {
  String get label => switch (this) {
    IncomeKind.earned => 'Kiếm được',
    IncomeKind.shareBill => 'Chia bill',
    IncomeKind.borrowed => 'Tiền vay',
  };

  /// Nhóm chi tiêu nói luôn đây là kiểu tiền vào nào — user không phải chọn
  /// thêm một lần nữa.
  ///
  /// Nhóm user tự đặt cho một khoản thu (thưởng, bán đồ cũ, tiền cho thuê...)
  /// đều là [earned]: mặc định phải là "kiếm được" chứ không phải "tiền của
  /// người khác", đoán nhầm hướng kia là báo hụt thu nhập mà không ai thấy.
  static IncomeKind fromCategory(String category) => switch (category) {
    Category.shareBill => IncomeKind.shareBill,
    Category.borrowed => IncomeKind.borrowed,
    _ => IncomeKind.earned,
  };
}

/// Một nhóm chi tiêu. User tự thêm, sửa, xoá ở màn "Nhóm chi tiêu".
///
/// Nhóm mang luôn bộ từ khoá dùng để đoán nhóm cho giao dịch mới: sửa nhóm là
/// sửa cả cách máy đoán, không phải hai chỗ rời nhau.
class Category {
  const Category({
    this.id,
    required this.name,
    this.keywords = const [],
    this.builtIn = false,
    this.sortOrder = 0,
  });

  factory Category.fromMap(Map<String, Object?> map) => Category(
    id: map['id'] as int?,
    name: map['name'] as String,
    keywords: parseKeywords(map['keywords'] as String?),
    builtIn: (map['built_in'] as int? ?? 0) == 1,
    sortOrder: map['sort_order'] as int? ?? 0,
  );

  /// Năm nhóm mà phần mềm tự nhắc tới tên: giao dịch nhập tay và khoản nợ rơi
  /// vào [uncategorized], tiền vào mặc định là [income], [shareBill] và
  /// [borrowed] là hai kiểu tiền vào không phải tiền kiếm được, còn
  /// [withdrawal] là dấu hiệu để coi một khoản rút ATM là chuyển ví chứ không
  /// phải khoản chi. Xoá hay đổi tên chúng thì các quy tắc đó gãy, nên chúng là
  /// nhóm hệ thống.
  static const String uncategorized = 'Khác';

  /// Chỗ mọi khoản tiền vào rơi vào khi chưa ai nói nó thuộc kiểu nào — lương
  /// là kiểu tiền vào thường gặp nhất và cũng là kiểu duy nhất kiếm ra được.
  static const String income = 'Lương';

  /// Người cùng bill trả lại phần của họ trong khoản mình đã ứng ra trả cho cả
  /// nhóm. Tiền vào ví nhưng không phải kiếm được: nó bù cho một khoản đã chi.
  static const String shareBill = 'Chia bill';

  /// Tiền mình vay của người khác — vào ví hôm nay, phải trả lại sau.
  static const String borrowed = 'Tiền vay';

  static const String withdrawal = 'Rút tiền';

  static const Set<String> builtInNames = {
    uncategorized,
    income,
    shareBill,
    borrowed,
    withdrawal,
  };

  /// Những nhóm chỉ dành cho tiền vào. Đoán nhóm cho một khoản thu chỉ xét từ
  /// khoá của mấy nhóm này — từ khoá "nhà hàng" của nhóm Ăn uống không được
  /// phép nuốt một khoản tiền vào.
  static const Set<String> incomeNames = {income, shareBill, borrowed};

  final int? id;
  final String name;

  /// Nội dung giao dịch chứa một trong các từ này thì xếp vào nhóm.
  /// Đã bỏ dấu và về chữ thường khi so khớp nên user gõ kiểu nào cũng được.
  final List<String> keywords;

  /// Nhóm hệ thống: sửa được từ khoá nhưng không đổi tên, không xoá.
  final bool builtIn;

  /// Thứ tự hiện trong danh sách chọn nhóm.
  final int sortOrder;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'keywords': keywords.join('\n'),
    'built_in': builtIn ? 1 : 0,
    'sort_order': sortOrder,
  };

  Category copyWith({String? name, List<String>? keywords, int? sortOrder}) =>
      Category(
        id: id,
        name: name ?? this.name,
        keywords: keywords ?? this.keywords,
        builtIn: builtIn,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  /// Đọc ô "từ khoá" user gõ: mỗi dòng hoặc mỗi dấu phẩy là một từ khoá.
  static List<String> parseKeywords(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[\n,]'))
        .map((word) => flatten(word.trim()))
        .where((word) => word.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Hai tên chỉ khác nhau ở dấu hoặc hoa thường thì coi là một nhóm — tránh
  /// để user tạo ra "Ăn uống" và "an uong" song song.
  static bool sameName(String a, String b) =>
      flatten(a.trim()) == flatten(b.trim());
}

/// Bộ nhóm dựng sẵn cho lần chạy đầu. Sau đó user muốn sửa gì thì sửa —
/// danh sách này chỉ là điểm xuất phát, không phải khuôn cố định.
const List<Category> defaultCategories = [
  Category(name: Category.income, builtIn: true, sortOrder: 0),
  Category(
    name: Category.shareBill,
    builtIn: true,
    sortOrder: 1,
    keywords: ['chia bill', 'share bill', 'tien bill', 'gop tien', 'chia tien'],
  ),
  Category(
    name: Category.borrowed,
    builtIn: true,
    sortOrder: 2,
    keywords: ['vay tien', 'tien vay', 'muon tien', 'di vay'],
  ),
  Category(
    name: 'Ăn uống',
    sortOrder: 3,
    keywords: [
      'highlands',
      'starbucks',
      'phuc long',
      'the coffee house',
      'cafe',
      'coffee',
      'tra sua',
      'nha hang',
      'quan an',
      'grabfood',
      'shopeefood',
      'baemin',
      'an uong',
    ],
  ),
  Category(
    name: 'Đi lại',
    sortOrder: 4,
    keywords: [
      'grab',
      'be group',
      'xanh sm',
      'taxi',
      'xang',
      'petrolimex',
      'vetau',
      'vexere',
      'vietjet',
      'bamboo airways',
      'vietnam airlines',
      'gui xe',
      'vetc',
      'epass',
    ],
  ),
  Category(
    name: 'Mua sắm',
    sortOrder: 5,
    keywords: [
      'shopee',
      'lazada',
      'tiki',
      'sendo',
      'tiktok shop',
      'winmart',
      'bach hoa xanh',
      'coopmart',
      'circle k',
      'gs25',
      'dien may',
      'the gioi di dong',
    ],
  ),
  Category(
    name: 'Hoá đơn',
    sortOrder: 6,
    keywords: [
      'evn',
      'tien dien',
      'tien nuoc',
      'internet',
      'fpt telecom',
      'viettel',
      'vinaphone',
      'mobifone',
      'truyen hinh',
      'cuoc',
      'hoa don',
    ],
  ),
  Category(
    name: 'Sức khoẻ',
    sortOrder: 7,
    keywords: [
      'benh vien',
      'phong kham',
      'nha thuoc',
      'pharmacity',
      'long chau',
      'guardian',
      'bao hiem',
    ],
  ),
  Category(
    name: 'Giải trí',
    sortOrder: 8,
    keywords: [
      'netflix',
      'spotify',
      'youtube',
      'cgv',
      'lotte cinema',
      'galaxy cinema',
      'steam',
      'game',
    ],
  ),
  Category(
    name: Category.withdrawal,
    builtIn: true,
    sortOrder: 9,
    keywords: ['rut tien', 'atm', 'withdrawal'],
  ),
  Category(
    name: 'Chuyển khoản',
    sortOrder: 10,
    keywords: ['chuyen tien', 'chuyen khoan', 'ck den', 'ck di', 'ib ft'],
  ),
  Category(name: Category.uncategorized, builtIn: true, sortOrder: 11),
];
