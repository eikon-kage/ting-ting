import 'package:flutter/material.dart';

import '../categories_page.dart';
import '../controllers/category_catalog.dart';

/// Hàng chip chọn nhóm, dùng chung cho màn nhập tay, sheet sửa giao dịch và
/// màn quy tắc.
///
/// Tự nghe [CategoryCatalog] nên user thêm hay xoá nhóm ở màn quản lý là hàng
/// chip này đổi theo, không cần màn gọi tự tải lại.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.manageable = true,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  /// Kèm chip mở màn quản lý nhóm — chỗ duy nhất user biết là mình sửa được.
  final bool manageable;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CategoryCatalog.instance,
      builder: (context, _) {
        final names = CategoryCatalog.instance.names;
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final name in names)
              ChoiceChip(
                label: Text(name),
                selected: selected == name,
                onSelected: (_) => onSelected(name),
              ),
            // Nhóm cũ của giao dịch có thể đã bị xoá khỏi danh sách — vẫn hiện
            // ra để user thấy nó đang thuộc nhóm nào.
            if (selected != null && !names.contains(selected))
              ChoiceChip(
                label: Text(selected!),
                selected: true,
                onSelected: (_) {},
              ),
            if (manageable)
              ActionChip(
                avatar: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Sửa nhóm'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CategoriesPage(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
