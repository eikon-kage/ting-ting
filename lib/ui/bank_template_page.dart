import 'package:flutter/material.dart';

import '../domain/bank_parser.dart';
import '../models/models.dart';
import 'controllers/bank_template_controller.dart';
import 'format.dart';
import 'theme/chart_palette.dart';

/// Khai mẫu bóc tách cho một ngân hàng.
///
/// Cách dùng: chọn một thông báo thật của app đó làm mẫu, gõ nhãn đứng trước
/// từng giá trị ("Số tiền giao dịch", "Số dư", "Nội dung") rồi nhìn khung xem
/// trước ở dưới — đọc đúng thì lưu. Ai cần chi li hơn thì mở phần regex.
class BankTemplatePage extends StatefulWidget {
  const BankTemplatePage({
    required this.packageName,
    required this.displayName,
    super.key,
  });

  final String packageName;
  final String displayName;

  @override
  State<BankTemplatePage> createState() => _BankTemplatePageState();
}

class _BankTemplatePageState extends State<BankTemplatePage> {
  late final BankTemplateController _controller = BankTemplateController(
    packageName: widget.packageName,
  );

  final _sampleTitle = TextEditingController();
  final _sampleContent = TextEditingController();
  final _amountLabel = TextEditingController();
  final _amountPattern = TextEditingController();
  final _balanceLabel = TextEditingController();
  final _balancePattern = TextEditingController();
  final _descLabel = TextEditingController();
  final _descPattern = TextEditingController();
  final _incomeHints = TextEditingController();
  final _expenseHints = TextEditingController();
  final _onlyIf = TextEditingController();
  final _ignoreIf = TextEditingController();

  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncFields);
    _controller.init();
  }

  @override
  void dispose() {
    _controller.removeListener(_syncFields);
    _controller.dispose();
    for (final c in [
      _sampleTitle,
      _sampleContent,
      _amountLabel,
      _amountPattern,
      _balanceLabel,
      _balancePattern,
      _descLabel,
      _descPattern,
      _incomeHints,
      _expenseHints,
      _onlyIf,
      _ignoreIf,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Đổ mẫu đã lưu vào các ô nhập một lần sau khi tải xong. Riêng ô thông báo
  /// mẫu còn phải theo kịp lúc user bấm chọn một thông báo khác.
  void _syncFields() {
    if (_controller.loading) return;
    if (!_filled) {
      final draft = _controller.draft;
      _amountLabel.text = draft.amountLabel;
      _amountPattern.text = draft.amountPattern;
      _balanceLabel.text = draft.balanceLabel;
      _balancePattern.text = draft.balancePattern;
      _descLabel.text = draft.descLabel;
      _descPattern.text = draft.descPattern;
      _incomeHints.text = ParserProfile.joinList(draft.incomeHints);
      _expenseHints.text = ParserProfile.joinList(draft.expenseHints);
      _onlyIf.text = ParserProfile.joinList(draft.onlyIf);
      _ignoreIf.text = ParserProfile.joinList(draft.ignoreIf);
      _filled = true;
    }
    if (_sampleTitle.text != _controller.sampleTitle) {
      _sampleTitle.text = _controller.sampleTitle;
    }
    if (_sampleContent.text != _controller.sampleContent) {
      _sampleContent.text = _controller.sampleContent;
    }
  }

  Future<void> _save() async {
    await _controller.save();
    final imported = await _controller.reparse();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          imported > 0
              ? 'Đã lưu mẫu, đọc lại nhật ký được thêm $imported giao dịch'
              : 'Đã lưu mẫu cho ${widget.displayName}',
        ),
      ),
    );
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá mẫu riêng?'),
        content: Text(
          '${widget.displayName} sẽ quay về cách đọc mặc định của app.',
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
    if (ok != true) return;
    _filled = false;
    await _controller.resetToDefault();
  }

  Future<void> _confirmLeave(bool didPop, Object? _) async {
    if (didPop || !_controller.dirty) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thoát mà không lưu?'),
        content: const Text('Những gì vừa sửa sẽ mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final loading = _controller.loading;
        return PopScope(
          canPop: !_controller.dirty,
          onPopInvokedWithResult: _confirmLeave,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.displayName, overflow: TextOverflow.ellipsis),
              actions: [
                if (!loading && !_controller.draft.isDefault)
                  IconButton(
                    tooltip: 'Xoá mẫu riêng',
                    icon: const Icon(Icons.restart_alt_rounded),
                    onPressed: _reset,
                  ),
              ],
            ),
            body: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _SampleCard(
                        controller: _controller,
                        titleField: _sampleTitle,
                        contentField: _sampleContent,
                      ),
                      _FieldCard(
                        title: 'Số tiền giao dịch',
                        hint: 'Ví dụ: Số tiền giao dịch, GD, Số tiền',
                        labelField: _amountLabel,
                        patternField: _amountPattern,
                        patternValid: _controller.amountPatternValid,
                        suggestions: _labelSuggestions(),
                        onLabel: (v) =>
                            _controller.edit((d) => d.copyWith(amountLabel: v)),
                        onPattern: (v) => _controller.edit(
                          (d) => d.copyWith(amountPattern: v),
                        ),
                      ),
                      _FieldCard(
                        title: 'Số dư sau giao dịch',
                        hint: 'Ví dụ: Số dư, SD',
                        labelField: _balanceLabel,
                        patternField: _balancePattern,
                        patternValid: _controller.balancePatternValid,
                        suggestions: _labelSuggestions(),
                        onLabel: (v) => _controller.edit(
                          (d) => d.copyWith(balanceLabel: v),
                        ),
                        onPattern: (v) => _controller.edit(
                          (d) => d.copyWith(balancePattern: v),
                        ),
                      ),
                      _FieldCard(
                        title: 'Nội dung giao dịch',
                        hint: 'Ví dụ: Nội dung, ND, Diễn giải',
                        labelField: _descLabel,
                        patternField: _descPattern,
                        patternValid: _controller.descPatternValid,
                        suggestions: _labelSuggestions(),
                        onLabel: (v) =>
                            _controller.edit((d) => d.copyWith(descLabel: v)),
                        onPattern: (v) =>
                            _controller.edit((d) => d.copyWith(descPattern: v)),
                      ),
                      _DirectionCard(
                        controller: _controller,
                        incomeField: _incomeHints,
                        expenseField: _expenseHints,
                      ),
                      _FilterCard(
                        controller: _controller,
                        onlyIfField: _onlyIf,
                        ignoreIfField: _ignoreIf,
                      ),
                    ],
                  ),
            bottomNavigationBar: loading
                ? null
                : _PreviewBar(controller: _controller, onSave: _save),
          ),
        );
      },
    );
  }

  /// Các nhãn tìm thấy trong thông báo mẫu ("Số dư:", "ND:"...) để user bấm
  /// chọn thay vì gõ tay — gõ sai một dấu là mẫu không khớp.
  List<String> _labelSuggestions() {
    final text = '${_controller.sampleTitle}\n${_controller.sampleContent}';
    final labels = <String>{};
    for (final m in RegExp(
      r'(?:^|[|\n])\s*([^:|\n]{2,30}?)\s*:',
      multiLine: true,
    ).allMatches(text)) {
      final label = m.group(1)?.trim();
      if (label != null && label.isNotEmpty) labels.add(label);
    }
    return labels.toList();
  }
}

/// Thông báo mẫu để thử: chọn từ nhật ký thật hoặc dán tay.
class _SampleCard extends StatelessWidget {
  const _SampleCard({
    required this.controller,
    required this.titleField,
    required this.contentField,
  });

  final BankTemplateController controller;
  final TextEditingController titleField;
  final TextEditingController contentField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final samples = controller.samples;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông báo mẫu', style: theme.textTheme.titleSmall),
            Text(
              'Chọn một thông báo thật của app này để thử mẫu bóc tách.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (samples.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: samples.length > 12 ? 12 : samples.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActionChip(
                    label: Text(
                      '${formatDay(samples[i].postTime)} '
                      '${formatTime(samples[i].postTime)}',
                    ),
                    onPressed: () => controller.useSample(samples[i]),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: titleField,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                isDense: true,
              ),
              onChanged: (v) => controller.editSample(title: v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentField,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                isDense: true,
              ),
              onChanged: (v) => controller.editSample(content: v),
            ),
            if (controller.sampleRedacted) ...[
              const SizedBox(height: 8),
              Text(
                'Android đã giấu nội dung thông báo này. Mẫu bóc tách không '
                'giúp được gì cho tới khi app được cấp quyền đọc thông báo '
                'nhạy cảm.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một giá trị cần bóc: khai bằng nhãn (dễ) hoặc regex (mạnh).
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.title,
    required this.hint,
    required this.labelField,
    required this.patternField,
    required this.patternValid,
    required this.suggestions,
    required this.onLabel,
    required this.onPattern,
  });

  final String title;
  final String hint;
  final TextEditingController labelField;
  final TextEditingController patternField;
  final bool patternValid;
  final List<String> suggestions;
  final ValueChanged<String> onLabel;
  final ValueChanged<String> onPattern;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: labelField,
              decoration: InputDecoration(
                labelText: 'Nhãn đứng trước giá trị',
                hintText: hint,
                helperText: 'Để trống = tự động dò như hiện nay',
                isDense: true,
              ),
              onChanged: onLabel,
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final label in suggestions)
                    ActionChip(
                      label: Text(label, style: theme.textTheme.bodySmall),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        labelField.text = label;
                        onLabel(label);
                      },
                    ),
                ],
              ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Nâng cao: regex', style: theme.textTheme.bodySmall),
              children: [
                TextField(
                  controller: patternField,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Regex',
                    helperText: 'Nhóm (?<num>…) là giá trị. Đè lên nhãn ở trên.',
                    errorText: patternValid ? null : 'Regex không hợp lệ',
                    isDense: true,
                  ),
                  onChanged: onPattern,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thu hay chi: theo dấu +/- (mặc định) hoặc ép cứng cho những app chỉ báo một
/// chiều.
class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.controller,
    required this.incomeField,
    required this.expenseField,
  });

  final BankTemplateController controller;
  final TextEditingController incomeField;
  final TextEditingController expenseField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = controller.draft.directionMode;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thu hay chi', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<DirectionMode>(
              segments: [
                for (final m in DirectionMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (values) => controller.edit(
                (d) => d.copyWith(directionMode: values.first),
              ),
            ),
            if (mode == DirectionMode.auto) ...[
              const SizedBox(height: 12),
              TextField(
                controller: incomeField,
                decoration: const InputDecoration(
                  labelText: 'Từ khoá báo tiền vào',
                  hintText: 'nhan tien, ghi co',
                  helperText: 'Ngăn nhau bằng dấu phẩy, cộng thêm vào bộ mặc định',
                  isDense: true,
                ),
                onChanged: (v) => controller.edit(
                  (d) => d.copyWith(incomeHints: ParserProfile.splitList(v)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expenseField,
                decoration: const InputDecoration(
                  labelText: 'Từ khoá báo tiền ra',
                  hintText: 'thanh toan, chuyen tien',
                  isDense: true,
                ),
                onChanged: (v) => controller.edit(
                  (d) => d.copyWith(expenseHints: ParserProfile.splitList(v)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chặn thông báo quảng cáo có kèm số tiền bị nhận nhầm thành giao dịch.
class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.controller,
    required this.onlyIfField,
    required this.ignoreIfField,
  });

  final BankTemplateController controller;
  final TextEditingController onlyIfField;
  final TextEditingController ignoreIfField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lọc thông báo', style: theme.textTheme.titleSmall),
            Text(
              'App ngân hàng còn bắn cả quảng cáo, khuyến mãi kèm số tiền.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: onlyIfField,
              decoration: const InputDecoration(
                labelText: 'Chỉ nhận khi có chữ',
                hintText: 'biến động số dư',
                helperText: 'Để trống = nhận mọi thông báo đọc ra tiền',
                isDense: true,
              ),
              onChanged: (v) => controller.edit(
                (d) => d.copyWith(onlyIf: ParserProfile.splitList(v)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ignoreIfField,
              decoration: const InputDecoration(
                labelText: 'Bỏ qua khi có chữ',
                hintText: 'khuyến mãi, ưu đãi, hoàn tiền tới',
                isDense: true,
              ),
              onChanged: (v) => controller.edit(
                (d) => d.copyWith(ignoreIf: ParserProfile.splitList(v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung xem trước dính đáy màn: mẫu vừa sửa đọc ra được gì trên thông báo mẫu.
class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.controller, required this.onSave});

  final BankTemplateController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = controller.preview;
    return Material(
      elevation: 3,
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đọc thử', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              if (!controller.hasSample)
                Text(
                  'Chưa có thông báo mẫu để thử.',
                  style: theme.textTheme.bodySmall,
                )
              else if (preview == null)
                Text(
                  'Chưa đọc ra giao dịch từ thông báo mẫu.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else
                _PreviewResult(preview: preview),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.dirty ? 'Có thay đổi chưa lưu' : 'Đã lưu',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Lưu mẫu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewResult extends StatelessWidget {
  const _PreviewResult({required this.preview});

  final ParseResult preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final income = preview.direction == TxnDirection.income;
    // Xanh cho thu, cam đỏ cho chi — giống hệt màn chính. Trước đây dùng
    // `primary` cho thu, giờ primary là cam nên đứng cạnh đỏ của chi rất dễ đọc
    // nhầm hướng tiền.
    final color = income ? palette.incomeText : palette.expenseText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              income ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              '${preview.direction.label} ${formatMoney(preview.amount)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!preview.directionConfident) ...[
              const SizedBox(width: 8),
              Text(
                'chưa chắc thu hay chi',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ],
        ),
        Text(
          'Số dư: ${preview.balance == null ? '—' : formatMoney(preview.balance!)}',
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'Nội dung: ${preview.description ?? '—'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
