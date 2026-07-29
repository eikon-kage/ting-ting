import 'package:flutter/material.dart';

import '../models/models.dart';
import 'controllers/rules_controller.dart';
import 'widgets/category_chips.dart';

/// Quy tắc tự phân loại: nội dung giao dịch chứa từ khoá nào thì vào nhóm nào.
/// Xét trước bộ từ khoá mặc định nên user luôn đè được lên máy đoán.
class RulesPage extends StatefulWidget {
  const RulesPage({super.key});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  final _controller = RulesController();

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
    final rule = await showModalBottomSheet<Rule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RuleSheet(),
    );
    if (rule == null) return;
    await _controller.add(rule);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Quy tắc phân loại')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm quy tắc'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rule_rounded,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có quy tắc riêng',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ví dụ: nội dung chứa "GUI ME" thì xếp vào nhóm Gia đình. '
                    'Quy tắc áp cho các giao dịch ghi nhận sau khi tạo.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          final rules = _controller.rules;
          return ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final rule = rules[i];
              return ListTile(
                title: Text('Chứa "${rule.keyword}"'),
                subtitle: Text(
                  rule.autoExclude
                      ? '${rule.category} · không tính vào báo cáo'
                      : rule.category,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _controller.remove(rule),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RuleSheet extends StatefulWidget {
  const _RuleSheet();

  @override
  State<_RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends State<_RuleSheet> {
  final _controller = TextEditingController();
  String _category = Category.uncategorized;
  bool _autoExclude = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text('Quy tắc mới', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nội dung có chứa',
                hintText: 'grab, tien nha, GUI ME...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Không phân biệt hoa thường và dấu tiếng Việt.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Xếp vào nhóm', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CategoryChips(
              selected: _category,
              onSelected: (category) => setState(() => _category = category),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoExclude,
              onChanged: (value) => setState(() => _autoExclude = value),
              title: const Text('Không tính vào báo cáo'),
              subtitle: const Text(
                'Dùng cho tiền tự chuyển giữa các tài khoản của mình',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  final keyword = _controller.text.trim();
                  if (keyword.isEmpty) return;
                  Navigator.of(context).pop(
                    Rule(
                      keyword: keyword,
                      category: _category,
                      autoExclude: _autoExclude,
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
