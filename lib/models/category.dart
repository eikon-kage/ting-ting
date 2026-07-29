import '../core/text.dart';

/// Kết quả khi ghi một nhóm — UI tự dịch ra câu báo cho user.
enum CategorySaveResult { ok, nameEmpty, nameTaken }

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

  /// Ba nhóm mà phần mềm tự nhắc tới tên: giao dịch nhập tay và khoản nợ rơi
  /// vào [uncategorized], tiền vào mặc định là [income], còn [withdrawal] là
  /// dấu hiệu để coi một khoản rút ATM là chuyển ví chứ không phải khoản chi.
  /// Xoá hay đổi tên chúng thì các quy tắc đó gãy, nên chúng là nhóm hệ thống.
  static const String uncategorized = 'Khác';
  static const String income = 'Thu nhập';
  static const String withdrawal = 'Rút tiền';

  static const Set<String> builtInNames = {uncategorized, income, withdrawal};

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
    name: 'Ăn uống',
    sortOrder: 1,
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
    sortOrder: 2,
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
    sortOrder: 3,
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
    sortOrder: 4,
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
    sortOrder: 5,
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
    sortOrder: 6,
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
    sortOrder: 7,
    keywords: ['rut tien', 'atm', 'withdrawal'],
  ),
  Category(
    name: 'Chuyển khoản',
    sortOrder: 8,
    keywords: ['chuyen tien', 'chuyen khoan', 'ck den', 'ck di', 'ib ft'],
  ),
  Category(name: Category.uncategorized, builtIn: true, sortOrder: 9),
];
