import '../core/text.dart';
import '../models/models.dart';

/// Nhóm được gợi ý cho một giao dịch.
class CategorySuggestion {
  const CategorySuggestion({required this.category, this.excluded = false});

  final String category;

  /// Quy tắc của user yêu cầu loại giao dịch này khỏi báo cáo.
  final bool excluded;
}

/// Đoán nhóm chi tiêu từ nội dung giao dịch. User sửa tay được trong app.
///
/// Bộ từ khoá không nằm ở đây nữa: mỗi nhóm tự mang từ khoá của nó và cả danh
/// sách nhóm thì user thêm sửa xoá được, nên nơi gọi phải truyền [categories]
/// đọc từ tầng dữ liệu xuống. Bộ dựng sẵn chỉ là chỗ dựa cho test.
class Categorizer {
  static const String uncategorized = Category.uncategorized;
  static const String income = Category.income;

  /// Rút tiền ATM chỉ là chuyển tiền sang ví tiền mặt, không phải khoản chi.
  static const String withdrawal = Category.withdrawal;

  /// Quy tắc do user tạo được xét trước từ khoá của nhóm.
  static CategorySuggestion categorize(
    String text,
    TxnDirection direction, {
    List<Rule> userRules = const [],
    List<Category> categories = defaultCategories,
  }) {
    final flat = flatten(text);
    for (final rule in userRules) {
      if (flat.contains(flatten(rule.keyword))) {
        return CategorySuggestion(
          category: rule.category,
          excluded: rule.autoExclude,
        );
      }
    }
    if (direction == TxnDirection.income) {
      return const CategorySuggestion(category: income);
    }
    for (final category in categories) {
      for (final keyword in category.keywords) {
        if (flat.contains(keyword)) {
          return CategorySuggestion(category: category.name);
        }
      }
    }
    return const CategorySuggestion(category: uncategorized);
  }

  /// Đọc nhóm ra từ chính chữ user gõ vào ô ghi chú của thông báo giao dịch.
  ///
  /// Ghi chú "ăn uống" là user đã nói thẳng giao dịch thuộc nhóm nào, nên khỏi
  /// bắt họ mở app chọn lại. Khác [categorize] ở ba chỗ:
  ///
  /// - Tên nhóm cũng được coi là từ khoá: gõ đúng tên nhóm là trúng, kể cả
  ///   nhóm user vừa tạo mà chưa khai từ khoá nào.
  /// - Không khớp được thì trả `null` chứ không đẩy về [uncategorized] — ghi
  ///   chú không nói gì về nhóm thì giữ nguyên nhóm máy đã đoán.
  /// - Không xét chiều tiền: user gõ gì thì theo nấy.
  static CategorySuggestion? categorizeNote(
    String note, {
    List<Rule> userRules = const [],
    List<Category> categories = defaultCategories,
  }) {
    final flat = flatten(note).trim();
    if (flat.isEmpty) return null;
    for (final rule in userRules) {
      if (flat.contains(flatten(rule.keyword))) {
        return CategorySuggestion(
          category: rule.category,
          excluded: rule.autoExclude,
        );
      }
    }
    // Tên nhóm được xét trước toàn bộ từ khoá: gọi thẳng tên ra là ý rõ ràng
    // hơn một từ khoá tình cờ trùng của nhóm nào đó đứng trên.
    for (final category in categories) {
      // "Khác" là chỗ đổ của cái không đoán được, gán tay vào đó chẳng để làm
      // gì; mà "khac" lại nằm sẵn trong "khach san", "khac phuc"...
      if (category.name == uncategorized) continue;
      if (flat.contains(flatten(category.name))) {
        return CategorySuggestion(category: category.name);
      }
    }
    for (final category in categories) {
      for (final keyword in category.keywords) {
        if (flat.contains(keyword)) {
          return CategorySuggestion(category: category.name);
        }
      }
    }
    return null;
  }
}
