import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'controllers/raw_log_controller.dart';
import 'format.dart';
import 'widgets/empty_state.dart';

/// Nhật ký mọi notification đi qua máy, kèm kết quả bóc tách.
///
/// Mặc định hiện tất cả — thông báo parser không đọc ra tiền chính là thứ cần
/// soi khi một ngân hàng nào đó không lên giao dịch. Lọc lại còn mỗi giao dịch
/// bằng nút phễu trên thanh tiêu đề.
class RawLogPage extends StatefulWidget {
  const RawLogPage({super.key});

  @override
  State<RawLogPage> createState() => _RawLogPageState();
}

class _RawLogPageState extends State<RawLogPage> {
  final _controller = RawLogController();

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

  Future<void> _addAsSource(RawLogEntry entry) async {
    final result = await _controller.enableSourceFor(entry.log);
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.imported > 0
              ? 'Đã bật ${result.name}, dựng lại ${result.imported} giao dịch'
              : 'Đã bật ${result.name}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhật ký thông báo'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: _controller.onlyTransactions
                  ? 'Đang chỉ hiện giao dịch'
                  : 'Chỉ hiện giao dịch',
              isSelected: _controller.onlyTransactions,
              icon: const Icon(Icons.filter_alt_outlined),
              selectedIcon: const Icon(Icons.filter_alt_rounded),
              onPressed: _controller.toggleFilter,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = _controller.entries;
          if (entries.isEmpty) {
            return _EmptyLog(filtered: _controller.onlyTransactions);
          }
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _LogTile(
                entry: entries[i],
                onAddSource: () => _addAsSource(entries[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry, required this.onAddSource});

  final RawLogEntry entry;
  final VoidCallback onAddSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = entry.log;
    final parsed = entry.parsed;
    return ExpansionTile(
      title: Text(
        log.title.isNotEmpty ? log.title : log.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatDay(log.postTime)} ${formatTime(log.postTime)} · ${log.packageName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: entry.isTransaction
          ? Icon(
              Icons.attach_money_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            )
          : null,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(log.content, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        if (parsed != null)
          Text(
            'Đọc được: ${parsed.direction.label} ${formatMoney(parsed.amount)}'
            '${parsed.balance != null ? ' · số dư ${formatMoney(parsed.balance!)}' : ''}'
            '${parsed.directionConfident ? '' : ' · chưa chắc thu hay chi'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          )
        else
          Text(
            'Không đọc ra được số tiền nào từ thông báo này.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy text gốc'),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: '${log.title}\n${log.content}'),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Đã copy')));
              },
            ),
            const Spacer(),
            if (entry.canBecomeSource)
              FilledButton.tonal(
                onPressed: onAddSource,
                child: const Text('Bật làm nguồn'),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyLog extends StatelessWidget {
  const _EmptyLog({required this.filtered});

  /// Đang bật lọc "chỉ giao dịch" — nhật ký có thể vẫn đầy thông báo thường.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.inbox_rounded,
      title: filtered
          ? 'Chưa đọc ra giao dịch nào'
          : 'Chưa nhận được thông báo nào',
      message: filtered
          ? 'Tắt bộ lọc để xem mọi thông báo đã nhận, rồi khai mẫu bóc tách '
                'cho app ngân hàng ở tab Ngân hàng.'
          : 'Kiểm tra lại quyền đọc thông báo ở màn hình chính.',
    );
  }
}
