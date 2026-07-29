import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/notification_privacy.dart';
import '../services/notification_capture.dart';
import 'bank_template_page.dart';
import 'controllers/bank_templates_controller.dart';
import 'format.dart';
import 'widgets/empty_state.dart';

/// Tab "Ngân hàng": mỗi app gửi thông báo một dòng, bật/tắt ghi nhận và khai
/// mẫu bóc tách riêng cho app đó.
///
/// Liệt kê cả những app parser chưa đọc ra được đồng nào — đó mới là chỗ cần
/// khai mẫu. Màn Nguồn cũ chỉ hiện app đã đọc được nên nhà băng nào format lạ
/// sẽ không bao giờ xuất hiện để mà sửa.
class BankTemplatesPage extends StatefulWidget {
  const BankTemplatesPage({super.key, this.reloadSignal});

  /// Tab vừa được chọn — nạp lại danh sách.
  final ValueNotifier<int>? reloadSignal;

  @override
  State<BankTemplatesPage> createState() => _BankTemplatesPageState();
}

class _BankTemplatesPageState extends State<BankTemplatesPage> {
  final _controller = BankTemplatesController();

  @override
  void initState() {
    super.initState();
    _controller.init();
    widget.reloadSignal?.addListener(_controller.refresh);
  }

  @override
  void dispose() {
    widget.reloadSignal?.removeListener(_controller.refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle(BankTemplateEntry entry, bool enabled) async {
    final imported = await _controller.setEnabled(entry, enabled: enabled);
    if (!mounted || imported == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã dựng lại $imported giao dịch từ nhật ký cũ')),
    );
  }

  Future<void> _pinWidget() async {
    if (await _controller.pinWidget() || !mounted) return;
    // Chỉ báo khi hỏng: lúc chạy được thì hộp thoại của hệ thống đã che hết
    // màn hình, snackbar nằm dưới đó không ai đọc.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Màn hình chính không nhận ô — thử thêm từ khay widget'),
      ),
    );
  }

  Future<void> _openTemplate(BankTemplateEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BankTemplatePage(
          packageName: entry.packageName,
          displayName: entry.displayName,
        ),
      ),
    );
    await _controller.refresh();
  }

  Future<void> _rename(BankTemplateEntry entry) async {
    final controller = TextEditingController(text: entry.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên ngân hàng'),
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
    await _controller.rename(entry, name);
    await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ngân hàng')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final capture = _controller.captureSupported
              ? _CaptureBanner(
                  running: _controller.capturing,
                  onChanged: (value) =>
                      _controller.setCapturing(enabled: value),
                )
              : null;
          final pinWidget = _controller.canPinWidget
              ? _PinWidgetTile(onTap: _pinWidget)
              : null;
          if (_controller.isEmpty) {
            // Expanded chứ không phải ListView: [_EmptyList] căn giữa theo
            // chiều cao nên cần một khung có chiều cao xác định.
            return Column(
              children: [
                ?capture,
                ?pinWidget,
                const Expanded(child: _EmptyList()),
              ],
            );
          }
          final active = _controller.active;
          final others = _controller.others;
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView(
              children: [
                ?capture,
                ?pinWidget,
                if (_controller.hasRedacted) const _RedactedBanner(),
                if (active.isNotEmpty) const _SectionHeader('Đang ghi nhận'),
                for (final entry in active) _tile(entry),
                if (others.isNotEmpty)
                  const _SectionHeader(
                    'App khác đã gửi thông báo — bật lên nếu là app ngân hàng',
                  ),
                for (final entry in others) _tile(entry),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BankTemplateEntry entry) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // App đang ghi nhận thì huy hiệu cam đậm, app chưa bật thì xám — nhìn dọc
    // danh sách là thấy ngay app nào đang chạy.
    final badge = entry.redacted
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : entry.enabled
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : (scheme.surfaceContainerHigh, scheme.onSurfaceVariant);
    return ListTile(
      onTap: () => _openTemplate(entry),
      onLongPress: () => _rename(entry),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: badge.$1, shape: BoxShape.circle),
        child: Icon(
          entry.redacted
              ? Icons.visibility_off_rounded
              : Icons.account_balance_rounded,
          size: 22,
          color: badge.$2,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(entry.displayName, overflow: TextOverflow.ellipsis),
          ),
          if (entry.hasProfile) ...[
            const SizedBox(width: 6),
            Icon(Icons.verified_rounded, size: 16, color: scheme.primary),
          ],
        ],
      ),
      subtitle: Text(
        [
          '${entry.logCount} thông báo',
          if (entry.lastAt != null) 'gần nhất ${formatDay(entry.lastAt!)}',
          if (entry.hasProfile) 'có mẫu riêng',
          if (entry.redacted) 'nội dung bị Android ẩn',
        ].join(' · '),
        maxLines: 2,
        style: theme.textTheme.bodySmall?.copyWith(
          color: entry.redacted ? scheme.error : null,
        ),
      ),
      trailing: Switch(
        value: entry.enabled,
        onChanged: (value) => _toggle(entry, value),
      ),
    );
  }
}

/// Trạng thái theo dõi nền — cái quyết định app có ghi được giao dịch lúc user
/// đã vuốt nó khỏi recents hay không.
///
/// Đáng để chiếm một ô to đầu màn: tắt cái này đi thì app chỉ ghi được lúc
/// đang mở, mà chuyện đó không nhìn đâu ra được nếu không nói thẳng.
class _CaptureBanner extends StatelessWidget {
  const _CaptureBanner({required this.running, required this.onChanged});

  final bool running;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NoticeBanner(
      icon: running
          ? Icons.radio_button_checked_rounded
          : Icons.pause_circle_outline_rounded,
      title: running ? 'Đang theo dõi nền' : 'Theo dõi nền đang tắt',
      message: running
          ? 'Giao dịch vẫn được ghi khi app đóng. Thông báo thường trực trên '
                'thanh trạng thái là của phần này — Android bắt buộc phải có.'
          : 'App chỉ ghi được giao dịch khi đang mở. Vuốt app khỏi recents là '
                'bỏ lỡ mọi thông báo cho tới lúc mở lại.',
      background: running
          ? scheme.primaryContainer
          : scheme.surfaceContainerHigh,
      foreground: running ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      action: Align(
        alignment: Alignment.centerLeft,
        child: running
            ? OutlinedButton.icon(
                onPressed: () => onChanged(false),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Tắt theo dõi'),
              )
            : FilledButton.icon(
                onPressed: () => onChanged(true),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Bật theo dõi'),
              ),
      ),
    );
  }
}

/// Nút đặt ô tổng quan ra màn hình chính.
///
/// Tưởng thừa — launcher nào chả có khay chọn widget — nhưng khay của HyperOS
/// không liệt kê widget của app bên thứ ba, nên trên máy Xiaomi đây là đường
/// duy nhất đặt được ô ra ngoài.
class _PinWidgetTile extends StatelessWidget {
  const _PinWidgetTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.widgets_outlined),
      title: const Text('Thêm ô thu chi ra màn hình chính'),
      subtitle: const Text(
        'Ô lớn hiện tiền đã chi tháng này, thu, còn lại và số dư.',
      ),
      trailing: const Icon(Icons.add_rounded),
      onTap: onTap,
    );
  }
}

/// Android 15 giấu nội dung thông báo ngân hàng với app đọc thông báo. Không
/// báo thì user ngồi sửa mẫu bóc tách cả buổi cũng không ra.
class _RedactedBanner extends StatelessWidget {
  const _RedactedBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NoticeBanner(
      icon: Icons.visibility_off_rounded,
      title: 'Android đang giấu nội dung thông báo',
      message:
          'Từ Android 15, thông báo ngân hàng bị coi là nhạy cảm: app chỉ '
          'nhận được câu "Sensitive notification content hidden" thay cho '
          'số tiền và nội dung. Mẫu bóc tách không cứu được, phải cấp quyền '
          'cho app.',
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _RedactedHelpDialog(),
        ),
        icon: const Icon(Icons.help_outline_rounded, size: 20),
        label: const Text('Cách cấp quyền'),
      ),
    );
  }
}

/// Ba bước cấp quyền `RECEIVE_SENSITIVE_NOTIFICATIONS`. Bước 3 hay bị bỏ quên
/// mà thiếu nó thì coi như chưa cấp: service đọc thông báo đã bind từ trước,
/// phải tắt bật lại mới bind lại với quyền mới.
class _RedactedHelpDialog extends StatelessWidget {
  const _RedactedHelpDialog();

  Future<void> _copy(BuildContext context, String command) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: command));
    messenger.showSnackBar(
      const SnackBar(content: Text('Đã copy lệnh, dán vào máy tính để chạy')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Cấp quyền đọc thông báo nhạy cảm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Android không cho app tự xin quyền này, phải cấp từ máy tính:',
              style: theme.textTheme.bodyMedium,
            ),
            const _HelpStep(
              1,
              'Bật Tuỳ chọn nhà phát triển > USB debugging, cắm máy vào máy '
              'tính rồi bấm "Cho phép" trên hộp thoại gỡ lỗi USB.',
            ),
            const _HelpStep(2, 'Chạy lệnh này trên máy tính:'),
            _CommandBox(
              command: sensitiveNotificationsAdbCommand,
              onCopy: () => _copy(context, sensitiveNotificationsAdbCommand),
            ),
            const _HelpStep(
              3,
              'Quay lại máy, tắt rồi bật lại quyền đọc thông báo của Ting '
              'Ting — chưa tắt bật lại thì quyền mới chưa có tác dụng.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: NotificationCapture.instance.requestPermission,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text('Mở cài đặt quyền đọc thông báo'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Máy nào báo lỗi ở bước 2 thì chạy lại lệnh trên nhưng bỏ phần '
              '"--uid". Không có máy tính thì cài Shizuku và chạy đúng lệnh '
              'đó (bỏ chữ "adb") trong terminal của Shizuku.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _copy(context, sensitiveNotificationsAdbCommand),
          child: const Text('Copy lệnh'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep(this.index, this.text);

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Lệnh adb dài hơn bề ngang dialog — cho cuộn ngang thay vì ngắt dòng lung
/// tung, để user nhìn ra đâu là một lệnh liền mạch.
class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command, required this.onCopy});

  final String command;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10, left: 32),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                command,
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy lệnh',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      margin: const EdgeInsets.only(top: 12),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.account_balance_rounded,
      title: 'Chưa nhận được thông báo nào',
      message:
          'Bật quyền đọc thông báo ở màn hình chính, rồi chờ app ngân hàng '
          'bắn một thông báo biến động số dư.',
    );
  }
}
