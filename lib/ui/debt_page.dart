import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'add_debt_page.dart';
import 'controllers/debt_controller.dart';
import 'format.dart';
import 'theme/chart_palette.dart';
import 'widgets/empty_state.dart';

/// Sổ nợ: ai đang nợ mình, mình đang nợ ai.
///
/// Số liệu ở đây tách hẳn khỏi Thu–Chi. Bố mẹ chuyển tiền cho mình không phải
/// thu nhập, mình chuyển lại cho bố mẹ cũng không phải chi tiêu — nó chỉ làm
/// số dư giữa hai bên thay đổi.
class DebtPage extends StatefulWidget {
  const DebtPage({super.key, this.reloadSignal});

  /// Bắn ra từ [RootShell] khi tab này được chọn lại, để nạp lại số liệu.
  final ValueListenable<int>? reloadSignal;

  @override
  State<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends State<DebtPage> {
  final _controller = DebtController();

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

  Future<void> _addDebt({String? person}) => Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => AddDebtPage(person: person)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sổ nợ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDebt,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ghi khoản nợ'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final overview = _controller.overview;
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  color: theme.colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    // A tint of the fill's own hue rather than `outline`: the
                    // neutral grey outline reads as a hard dirty edge once the
                    // card is tinted again.
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Cell(
                            icon: Icons.call_received_rounded,
                            label: 'Người khác nợ mình',
                            value: formatMoney(overview.theyOweMe),
                            color: palette.incomeText,
                          ),
                        ),
                        Expanded(
                          child: _Cell(
                            icon: Icons.call_made_rounded,
                            label: 'Mình nợ người khác',
                            value: formatMoney(overview.iOweThem),
                            color: palette.expenseText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (overview.unassigned.isNotEmpty) ...[
                  const _Header('Chưa gán tên người'),
                  for (final txn in overview.unassigned)
                    ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 22,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      title: Text(
                        '${txn.debtType!.label} ${formatMoney(txn.amount)}',
                      ),
                      subtitle: Text(
                        txn.description ?? formatDay(txn.postTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showAssignDebtSheet(context, txn),
                    ),
                ],
                if (overview.people.isEmpty)
                  const _EmptyDebt()
                else ...[
                  const _Header('Theo từng người'),
                  for (final entry in overview.people)
                    ListTile(
                      leading: CircleAvatar(
                        radius: 21,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          entry.person.substring(0, 1).toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(entry.person),
                      subtitle: Text('${entry.count} giao dịch'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            entry.theyOweMe ? 'Nợ mình' : 'Mình nợ',
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            formatMoney(entry.balance.abs()),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: entry.theyOweMe
                                  ? palette.incomeText
                                  : palette.expenseText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PersonDebtPage(person: entry.person),
                        ),
                      ),
                    ),
                ],
                // Chừa chỗ cho nút "Ghi khoản nợ" khỏi che dòng cuối.
                const SizedBox(height: 88),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lịch sử vay/trả với một người.
class _PersonDebtPage extends StatefulWidget {
  const _PersonDebtPage({required this.person});

  final String person;

  @override
  State<_PersonDebtPage> createState() => _PersonDebtPageState();
}

class _PersonDebtPageState extends State<_PersonDebtPage> {
  late final _controller = PersonDebtController(person: widget.person);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.person)),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ghi khoản nợ với ${widget.person}',
        onPressed: () => Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => AddDebtPage(person: widget.person),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final txns = _controller.txns;
          final balance = _controller.balance;
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  children: [
                    Text(
                      balance >= 0 ? 'Đang nợ mình' : 'Mình đang nợ',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatMoney(balance.abs()),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: balance >= 0
                            ? palette.incomeText
                            : palette.expenseText,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: txns.length,
                  itemBuilder: (_, i) {
                    final txn = txns[i];
                    final adds = txn.debtEffect > 0;
                    final color = adds
                        ? palette.incomeText
                        : palette.expenseText;
                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          adds
                              ? Icons.call_received_rounded
                              : Icons.call_made_rounded,
                          size: 22,
                          color: color,
                        ),
                      ),
                      title: Text(txn.debtType!.label),
                      subtitle: Text(
                        '${formatDay(txn.postTime)} · ${txn.description ?? txn.bankName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        formatSigned(txn.amount, isIncome: adds),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => showAssignDebtSheet(context, txn),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sheet gán một giao dịch vào sổ nợ: chọn loại và tên người.
/// Cũng dùng cho luồng bấm nút "Cho vay" trên thông báo.
Future<void> showAssignDebtSheet(BuildContext context, Txn txn) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AssignDebtSheet(txn: txn),
  );
}

class _AssignDebtSheet extends StatefulWidget {
  const _AssignDebtSheet({required this.txn});

  final Txn txn;

  @override
  State<_AssignDebtSheet> createState() => _AssignDebtSheetState();
}

class _AssignDebtSheetState extends State<_AssignDebtSheet> {
  late final _person = TextEditingController(text: widget.txn.person ?? '');
  late final _controller = AssignDebtController(txn: widget.txn);

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _person.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await _controller.save(_person.text);
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _removeFromDebt() async {
    await _controller.release();
    if (mounted) Navigator.of(context).pop();
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
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ghi vào sổ nợ', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${formatMoney(widget.txn.amount)} · ${widget.txn.description ?? widget.txn.bankName}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SegmentedButton<DebtType>(
                segments: [
                  for (final option in _controller.options)
                    ButtonSegment(value: option, label: Text(option.label)),
                ],
                selected: {_controller.type},
                onSelectionChanged: (s) => _controller.selectType(s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _person,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Với ai',
                  hintText: 'Bố mẹ, Nam, chị Lan...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
              if (_controller.suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final name in _controller.suggestions.take(6))
                      ActionChip(
                        label: Text(name),
                        onPressed: () => _person.text = name,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.txn.isDebt)
                    TextButton(
                      onPressed: _removeFromDebt,
                      child: const Text('Bỏ khỏi sổ nợ'),
                    ),
                  const Spacer(),
                  FilledButton(onPressed: _save, child: const Text('Lưu')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: onContainer),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onContainer,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      margin: const EdgeInsets.only(top: 8),
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

class _EmptyDebt extends StatelessWidget {
  const _EmptyDebt();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.volunteer_activism_rounded,
      title: 'Chưa có khoản nợ nào',
      message:
          'Bấm "Ghi khoản nợ" để thêm tay, hoặc mở một giao dịch có sẵn rồi '
          'chọn "Ghi vào sổ nợ". Khi ngân hàng bắn thông báo cũng có nút '
          'Cho vay / Thu nợ ngay trên đó.',
    );
  }
}
