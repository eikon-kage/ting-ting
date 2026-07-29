// `foundation` cũng có một lớp tên Category (chú thích cho dartdoc), che đi để
// tên nhóm của app không bị lẫn.
import 'package:flutter/foundation.dart' hide Category;

import '../../data/data_store.dart';
import '../../models/models.dart';

/// Danh sách nhóm đang có, giữ sẵn trong bộ nhớ cho mọi màn hình dùng chung.
///
/// Các ô chọn nhóm nằm rải khắp app (nhập tay, sửa giao dịch, lọc, quy tắc) và
/// đều vẽ trong `build`, không chờ được một `Future`. Nên danh sách được tải
/// một lần lúc mở app rồi tự nạp lại mỗi khi chuông `data.changes` reo — user
/// vừa thêm nhóm ở màn quản lý là các màn khác thấy ngay.
///
/// Sống suốt vòng đời app nên không ai `dispose` nó.
class CategoryCatalog extends ChangeNotifier {
  CategoryCatalog({DataStore? data}) : _data = data ?? DataStore.instance;

  static final CategoryCatalog instance = CategoryCatalog();

  final DataStore _data;
  bool _started = false;

  /// Bộ dựng sẵn dùng tạm cho khung hình đầu tiên, trước khi đọc xong bảng —
  /// để ô chọn nhóm không loé lên trống rỗng.
  List<Category> _categories = defaultCategories;

  List<Category> get categories => _categories;

  List<String> get names => [for (final c in _categories) c.name];

  Future<void> init() async {
    if (_started) return;
    _started = true;
    _data.changes.addListener(refresh);
    await refresh();
  }

  Future<void> refresh() async {
    final loaded = await _data.categories.all();
    // Bảng rỗng chỉ xảy ra khi chưa kịp đổ dữ liệu mẫu; giữ bộ đang có còn hơn
    // hiện ra một danh sách trắng.
    if (loaded.isEmpty) return;
    _categories = loaded;
    notifyListeners();
  }
}
