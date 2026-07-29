/// Quy tắc tự phân loại do user tạo: nội dung chứa [keyword] thì xếp vào
/// [category]. Được áp trước bộ từ khoá mặc định.
class Rule {
  Rule({
    this.id,
    required this.keyword,
    required this.category,
    this.autoExclude = false,
  });

  factory Rule.fromMap(Map<String, Object?> map) => Rule(
    id: map['id'] as int?,
    keyword: map['keyword'] as String,
    category: map['category'] as String,
    autoExclude: (map['auto_exclude'] as int? ?? 0) == 1,
  );

  final int? id;
  final String keyword;
  final String category;

  /// Khớp quy tắc này thì đánh dấu luôn "không tính vào báo cáo" —
  /// tiện cho việc tự chuyển tiền qua lại giữa các tài khoản của mình.
  final bool autoExclude;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'keyword': keyword,
    'category': category,
    'auto_exclude': autoExclude ? 1 : 0,
  };
}
