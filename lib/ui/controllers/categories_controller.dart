import '../../models/models.dart';
import 'base_controller.dart';

/// Màn quản lý nhóm chi tiêu.
class CategoriesController extends BaseController {
  CategoriesController({super.data});

  List<Category> _categories = const [];
  Map<String, int> _counts = const {};

  List<Category> get categories => _categories;
  bool get isEmpty => _categories.isEmpty;

  /// Số giao dịch đang mang nhóm này — hiện kèm để user biết mình sắp đụng vào
  /// bao nhiêu khoản khi xoá.
  int countOf(Category category) => _counts[category.name] ?? 0;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _categories = await data.categories.all();
    _counts = await data.categories.txnCounts();
  });

  Future<CategorySaveResult> add({
    required String name,
    required List<String> keywords,
  }) => data.categories.add(name: name, keywords: keywords);

  Future<CategorySaveResult> save(
    Category category, {
    required String name,
    required List<String> keywords,
  }) => data.categories.save(category, name: name, keywords: keywords);

  Future<bool> remove(Category category) => data.categories.remove(category);
}
