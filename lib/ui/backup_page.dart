import 'package:flutter/material.dart';

import '../domain/backup.dart';
import 'controllers/backup_controller.dart';
import 'format.dart';
import 'widgets/empty_state.dart';

/// Sao lưu và khôi phục.
///
/// Toàn bộ sổ sách nằm trong một file trên máy này. Màn này là đường duy nhất
/// để nó tồn tại ở chỗ khác — nên nó nói thẳng điều đó ngay dòng đầu, thay vì
/// nằm im như một mục cài đặt kỹ thuật.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _controller = BackupController();

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

  void _report(BackupOutcome? outcome) {
    if (outcome == null || !mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.message),
        backgroundColor: outcome.failed ? scheme.errorContainer : null,
        showCloseIcon: outcome.failed,
      ),
    );
  }

  Future<void> _exportBackup() async => _report(
    await _controller.exportBackup(),
  );

  Future<void> _exportCsv() async {
    final month = await _pickMonth();
    if (month == null) return;
    _report(await _controller.exportCsv(month: month.value));
  }

  /// Chọn tháng để xuất, kèm lựa chọn "tất cả". Bọc trong [_Choice] để phân
  /// biệt "user chọn tất cả" với "user đóng hộp thoại".
  Future<_Choice<DateTime?>?> _pickMonth() async {
    final months = await _controller.monthsWithData();
    if (!mounted) return null;
    return showModalBottomSheet<_Choice<DateTime?>>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Xuất giao dịch của',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive_rounded),
              title: const Text('Tất cả'),
              onTap: () => Navigator.of(
                sheetContext,
              ).pop(const _Choice<DateTime?>(null)),
            ),
            for (final month in months)
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(formatMonth(month)),
                onTap: () => Navigator.of(sheetContext).pop(_Choice(month)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore() async {
    final BackupData? backup;
    try {
      backup = await _controller.pickBackup();
    } on BackupError catch (e) {
      _report(BackupOutcome.failed(e.message));
      return;
    }
    if (backup == null || !mounted) return;

    final mode = await _pickRestoreMode(backup);
    if (mode == null) return;
    _report(await _controller.restore(backup, mode: mode));
  }

  Future<RestoreMode?> _pickRestoreMode(BackupData backup) => showDialog<RestoreMode>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Nạp bản sao lưu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File ngày ${formatDay(backup.createdAt)}, '
            '${backup.countOf('txns')} giao dịch.',
          ),
          const SizedBox(height: 16),
          for (final mode in RestoreMode.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                mode == RestoreMode.merge
                    ? Icons.merge_rounded
                    : Icons.settings_backup_restore_rounded,
                color: mode == RestoreMode.replace
                    ? Theme.of(dialogContext).colorScheme.error
                    : null,
              ),
              title: Text(mode.label),
              subtitle: Text(mode.hint),
              onTap: () => Navigator.of(dialogContext).pop(mode),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Huỷ'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final busy = _controller.busy;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const NoticeBanner(
                icon: Icons.cloud_off_rounded,
                title: 'Dữ liệu chỉ nằm trên máy này',
                message:
                    'App không gửi gì lên mạng. Đổi máy hay mất máy mà chưa sao '
                    'lưu thì toàn bộ sổ sách mất theo.',
              ),
              const _SectionHeader('Đưa dữ liệu ra ngoài'),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Tạo bản sao lưu'),
                subtitle: Text(
                  'Một file JSON gồm ${_controller.txnCount} giao dịch, '
                  'nhóm chi tiêu, quy tắc và mẫu bóc tách',
                ),
                enabled: !busy,
                onTap: _exportBackup,
              ),
              SwitchListTile(
                value: _controller.includeRawLogs,
                onChanged: busy ? null : _controller.setIncludeRawLogs,
                secondary: const Icon(Icons.notifications_none_rounded),
                title: const Text('Kèm nhật ký thông báo'),
                subtitle: const Text(
                  'File nặng hơn nhiều, nhưng bật nguồn muộn vẫn dựng lại được '
                  'giao dịch cũ',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Xuất bảng giao dịch (CSV)'),
                subtitle: const Text('Mở được bằng Excel hay Google Sheets'),
                enabled: !busy,
                onTap: _exportCsv,
              ),
              const _SectionHeader('Nhận dữ liệu vào'),
              ListTile(
                leading: const Icon(Icons.restore_page_outlined),
                title: const Text('Nạp từ bản sao lưu'),
                subtitle: const Text(
                  'Chọn file JSON đã tạo trước đó, gộp thêm hoặc thay thế toàn bộ',
                ),
                enabled: !busy,
                onTap: _restore,
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Bọc một giá trị có thể là `null` để phân biệt với "không chọn gì".
class _Choice<T> {
  const _Choice(this.value);

  final T value;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
