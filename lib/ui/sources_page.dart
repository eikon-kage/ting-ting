import 'package:flutter/material.dart';

import '../models/models.dart';
import 'controllers/sources_controller.dart';
import 'widgets/empty_state.dart';

/// Danh sách app được coi là nguồn giao dịch.
///
/// App tự phát hiện: notification nào bóc tách ra được số tiền thì app gửi nó
/// sẽ xuất hiện ở đây dưới dạng "chờ bật". Cách này khỏi phải đoán trước tên
/// package của từng ngân hàng — cứ dùng máy vài hôm là chúng tự hiện ra.
class SourcesPage extends StatefulWidget {
  const SourcesPage({super.key});

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  final _controller = SourcesController();

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

  Future<void> _toggle(Source source, bool enabled) async {
    final imported = await _controller.setEnabled(source, enabled: enabled);
    if (!mounted || imported == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã dựng lại $imported giao dịch từ nhật ký cũ')),
    );
  }

  Future<void> _rename(Source source) async {
    final controller = TextEditingController(text: source.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên nguồn'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên hiển thị'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _controller.rename(source, name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nguồn ngân hàng')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.isEmpty) return const _EmptySources();
          final enabled = _controller.enabled;
          final pending = _controller.pending;
          return ListView(
            children: [
              if (enabled.isNotEmpty) const _SectionHeader('Đang ghi nhận'),
              for (final source in enabled) _tile(source),
              if (pending.isNotEmpty)
                const _SectionHeader(
                  'Chờ bật — app này có gửi thông báo dạng giao dịch',
                ),
              for (final source in pending) _tile(source),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(Source source) => SwitchListTile(
    value: source.enabled,
    onChanged: (value) => _toggle(source, value),
    title: Text(source.displayName),
    subtitle: Text(
      source.packageName,
      style: Theme.of(context).textTheme.bodySmall,
    ),
    secondary: IconButton(
      icon: const Icon(Icons.edit_rounded),
      tooltip: 'Đổi tên',
      onPressed: () => _rename(source),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.account_balance_rounded,
      title: 'Chưa phát hiện app ngân hàng nào',
      message:
          'Chờ app ngân hàng bắn một thông báo biến động số dư, nó sẽ tự hiện '
          'ở đây. Hoặc mở Nhật ký thông báo để thêm thủ công.',
    );
  }
}
