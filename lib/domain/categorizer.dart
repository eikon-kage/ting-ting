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
}
