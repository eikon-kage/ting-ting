import 'package:flutter/material.dart';

import '../models/models.dart';
import 'controllers/categories_controller.dart';
import 'theme/chart_palette.dart';
import 'widgets/empty_state.dart';

/// Quản lý nhóm chi tiêu: thêm, sửa tên và từ khoá, xoá.
///
/// Năm nhóm "Lương", "Chia bill", "Tiền vay", "Rút tiền", "Khác" là nhóm hệ
/// thống — phần mềm tự nhắc tới tên chúng (tiền vào mặc định là Lương, khoản
/// người ta trả lại tiền bill được trừ khỏi số đã chi, tiền vay là tiền phải
/// trả lại chứ không phải kiếm được, rút ATM được coi là chuyển ví, khoản chưa
/// phân loại rơi vào Khác) nên chỉ sửa được từ khoá.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _controller = CategoriesController();

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final draft = await showModalBottomSheet<_CategoryDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CategorySheet(),
    );
    if (draft == null) return;
    final result = await _controller.add(
      name: draft.name,
      keywords: draft.keywords,
    );
    _report(result, done: 'Đã thêm nhóm ${draft.name}');
  }

  Future<void> _edit(Category category) async {
    final draft = await showModalBottomSheet<_CategoryDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategorySheet(category: category),
    );
    if (draft == null) return;
    final result = await _controller.save(
      category,
      name: draft.name,
      keywords: draft.keywords,
    );
    _report(
      result,
      done: draft.name == category.name
          ? 'Đã lưu nhóm ${category.name}'
          : 'Đã đổi "${category.name}" thành "${draft.name}"',
    );
  }

  Future<void> _delete(Category category) async {
    final count = _controller.countOf(category);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xoá nhóm ${category.name}?'),
        content: Text(
          count == 0
              ? 'Nhóm này chưa có giao dịch nào.'
              : '$count giao dịch đang thuộc nhóm này sẽ chuyển sang nhóm '
                    '"${Category.uncategorized}". Số tiền không đổi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _controller.remove(category);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã xoá nhóm ${category.name}')));
  }

  void _report(CategorySaveResult result, {required String done}) {
    if (!mounted) return;
    final message = switch (result) {
      CategorySaveResult.ok => done,
      CategorySaveResult.nameEmpty => 'Nhóm phải có tên',
      CategorySaveResult.nameTaken => 'Đã có nhóm tên này rồi',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhóm chi tiêu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm nhóm'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.isEmpty) {
            return const EmptyState(
              icon: Icons.category_rounded,
              title: 'Chưa có nhóm nào',
              message:
                  'Thêm nhóm để chia khoản chi theo cách của bạn: Ăn uống, '
                  'Con cái, Nhà cửa...',
            );
          }
          final categories = _controller.categories;
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) =>
                _tile(categories[i], _controller.countOf(categories[i]), i),
          );
        },
      ),
    );
  }

  /// [rank] is the row's position in the list, which picks the avatar colour.
  ///
  /// Every avatar used to be the same `primaryContainer` circle, so a list of
  /// twenty groups read as one column of identical dots and nothing could be
  /// found by sight. [ChartPalette] is borrowed because its six colours are
  /// already checked to stay apart for colour-blind readers — the property that
  /// matters when the dots sit one above another.
  ///
  /// Cycled with `%`, so the seventh group starts the palette over instead of
  /// falling into the grey "Khác" slot. Grey there would read as a real
  /// category state rather than as running out of colours.
  ///
  /// Deliberately does *not* line up with the report chart. That chart colours
  /// by rank of spend within the period, so a group's slice colour moves as
  /// spending moves; there is no stable per-category colour to match. This is
  /// decoration for scanning the list, nothing more — do not build meaning on
  /// it, and if the chart ever gains stable category colours, drop this in
  /// favour of them.
  Widget _tile(Category category, int count, int rank) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final color = palette.series(rank % palette.maxSlots);
    final keywords = category.keywords.isEmpty
        ? 'Chưa có từ khoá tự nhận'
        : category.keywords.take(4).join(', ') +
              (category.keywords.length > 4
                  ? ' +${category.keywords.length - 4}'
                  : '');
    return ListTile(
      onTap: () => _edit(category),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(
          category.builtIn ? Icons.lock_outline_rounded : Icons.label_outline,
          size: 20,
          color: color,
        ),
      ),
      title: Text(category.name),
      subtitle: Text(
        '$keywords · $count giao dịch',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: category.builtIn
          ? IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Sửa từ khoá',
              onPressed: () => _edit(category),
            )
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Xoá nhóm',
              onPressed: () => _delete(category),
            ),
    );
  }
}

/// Nội dung user vừa gõ trong sheet, trả ngược ra cho màn danh sách.
class _CategoryDraft {
  const _CategoryDraft(this.name, this.keywords);

  final String name;
  final List<String> keywords;
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.category});

  /// `null` là thêm mới.
  final Category? category;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late final _keywordController = TextEditingController(
    text: widget.category?.keywords.join(', ') ?? '',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = widget.category;
    final locked = category?.builtIn ?? false;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category == null ? 'Nhóm mới' : 'Sửa nhóm',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: category == null,
              enabled: !locked,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tên nhóm',
                hintText: 'Con cái, Nhà cửa, Học hành...',
                border: const OutlineInputBorder(),
                helperText: locked
                    ? 'Nhóm hệ thống — app dùng tên này nên không đổi được'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keywordController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Từ khoá tự nhận (không bắt buộc)',
                hintText: 'shopee, tien dien, hoc phi',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ngăn cách bằng dấu phẩy. Giao dịch mới có nội dung chứa một '
              'trong các từ này sẽ tự vào nhóm. Không phân biệt hoa thường và '
              'dấu tiếng Việt.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  final name = locked
                      ? category!.name
                      : _nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(context).pop(
                    _CategoryDraft(
                      name,
                      Category.parseKeywords(_keywordController.text),
                    ),
                  );
                },
                child: const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
