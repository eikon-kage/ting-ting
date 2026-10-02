import 'package:flutter/material.dart';

import '../domain/bill_split.dart';
import '../models/models.dart';
import 'controllers/bill_controller.dart';
import 'format.dart';
import 'theme/chart_palette.dart';
import 'widgets/empty_state.dart';

/// Một cuộc chia tiền: ghi từng khoản ai đã trả, app tính ra ai đưa ai bao
/// nhiêu là xong.
class BillPage extends StatefulWidget {
  const BillPage({super.key, required this.billKey});

  final String billKey;

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  late final _controller = BillController(billKey: widget.billKey);

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

  Future<void> _editItem([BillItem? item]) async {
    final bill = _controller.bill;
    if (bill == null) return;
    final result = await showModalBottomSheet<_ItemResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _ItemSheet(billKey: bill.key, members: bill.members, item: item),
    );
    if (result == null) return;
    if (result.deleted) {
      await _controller.removeItem(result.item.key);
      return;
    }
    await _controller.saveItem(result.item);
  }

  Future<void> _addPeople() async {
    final bill = _controller.bill;
    if (bill == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );
    if (name == null) return;
    await _controller.addMembers([name]);
  }

  Future<void> _rename() async {
    final bill = _controller.bill;
    if (bill == null) return;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(current: bill.title),
    );
    if (title == null) return;
    await _controller.rename(title);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá bill này?'),
        content: const Text(
          'Cả các khoản đã ghi bên trong cũng mất. Giao dịch trong sổ Thu–Chi '
          'không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _controller.remove();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _removeRepayment(String person) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bỏ khoản $person đã trả?'),
        content: const Text(
          'Bill sẽ tính lại như thể chưa nhận được tiền. Giao dịch trong sổ '
          'Thu–Chi vẫn giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bỏ'),
          ),
        ],
      ),
    );
    if (ok == true) await _controller.removeRepayment(person);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final bill = _controller.bill;
        return Scaffold(
          appBar: AppBar(
            title: Text(bill?.title ?? 'Chia bill'),
            actions: [
              if (bill != null)
                PopupMenuButton<String>(
                  onSelected: (value) => switch (value) {
                    'rename' => _rename(),
                    'member' => _addPeople(),
                    'settled' => _controller.toggleSettled(),
                    _ => _delete(),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Đổi tên'),
                    ),
                    const PopupMenuItem(
                      value: 'member',
                      child: Text('Thêm người'),
                    ),
                    PopupMenuItem(
                      value: 'settled',
                      child: Text(
                        bill.settled ? 'Mở lại bill' : 'Đánh dấu đã xong',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Xoá bill'),
                    ),
                  ],
                ),
            ],
          ),
          floatingActionButton: bill == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: _editItem,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Thêm khoản'),
                ),
          body: _controller.loading
              ? const Center(child: CircularProgressIndicator())
              : bill == null
              ? const _Missing()
              : _BillBody(
                  bill: bill,
                  items: _controller.items,
                  settlement: _controller.settlement,
                  onItemTap: _editItem,
                  onAddPeople: _addPeople,
                  isMemberInUse: _controller.memberInUse,
                  removeMember: _controller.removeMember,
                  removeRepayment: _removeRepayment,
                ),
        );
      },
    );
  }
}

class _BillBody extends StatelessWidget {
  const _BillBody({
    required this.bill,
    required this.items,
    required this.settlement,
    required this.onItemTap,
    required this.onAddPeople,
    required this.isMemberInUse,
    required this.removeMember,
    required this.removeRepayment,
  });

  final Bill bill;
  final List<BillItem> items;
  final BillSettlement settlement;
  final void Function(BillItem item) onItemTap;
  final VoidCallback onAddPeople;

  /// Người đang có mặt trong một khoản nào đó thì không gỡ ra được.
  final bool Function(String person) isMemberInUse;
  final Future<void> Function(String person) removeMember;
  final Future<void> Function(String person) removeRepayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Totals(settlement: settlement, settled: bill.settled),
        _Section(
          title: 'Ai đi cùng',
          trailing: TextButton.icon(
            onPressed: onAddPeople,
            icon: const Icon(Icons.person_add_alt_rounded, size: 18),
            label: const Text('Thêm'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final member in bill.members)
                if (member == Bill.me || isMemberInUse(member))
                  Chip(label: Text(member))
                else
                  InputChip(
                    label: Text(member),
                    onDeleted: () => removeMember(member),
                  ),
            ],
          ),
        ),
        const _Section(title: 'Đã tiêu những gì'),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              'Chưa có khoản nào. Bấm "Thêm khoản" để ghi ai đã trả cái gì.',
            ),
          )
        else
          for (final item in items)
            _ItemTile(
              item: item,
              members: bill.members,
              onTap: () => onItemTap(item),
            ),
        const _Section(title: 'Chốt sổ'),
        if (settlement.transfers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              items.isEmpty
                  ? 'Ghi vài khoản rồi app tính giúp ai phải đưa ai bao nhiêu.'
                  : 'Không ai nợ ai — cả nhóm đã cân bằng.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final transfer in settlement.transfers)
            _TransferTile(transfer: transfer),
        for (final entry in bill.repaid.entries)
          _RepaidTile(
            person: entry.key,
            amount: entry.value,
            onRemove: () => removeRepayment(entry.key),
          ),
        const _Section(title: 'Từng người'),
        for (final member in settlement.members) _MemberTile(member: member),
      ],
    );
  }
}

/// Tổng bill và phần của chính mình.
class _Totals extends StatelessWidget {
  const _Totals({required this.settlement, required this.settled});

  final BillSettlement settlement;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final net = settlement.myNet;
    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: 'Tổng cả bill',
                    value: formatMoney(settlement.total),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Phần của bạn',
                    value: formatMoney(settlement.myShare),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            if (net != 0 && !settled) ...[
              const SizedBox(height: 14),
              Text(
                net > 0
                    ? 'Bạn đang được nhận lại ${formatMoney(net)}'
                    : 'Bạn còn phải đưa ${formatMoney(-net)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: net > 0 ? palette.incomeText : palette.expenseText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (settled) ...[
              const SizedBox(height: 14),
              Text(
                'Bill đã tất toán.',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color)),
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

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.members,
    required this.onTap,
  });

  final BillItem item;
  final List<String> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shares = itemShares(item, members);
    final mine = shares[Bill.me] ?? 0;
    return ListTile(
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          item.payer.substring(0, 1).toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      title: Text(item.label.isEmpty ? 'Khoản chung' : item.label),
      subtitle: Text(
        '${item.payer} trả · ${_splitLabel(item, shares.length)}'
        '${mine > 0 ? ' · phần bạn ${formatMoney(mine)}' : ''}',
        maxLines: 2,
      ),
      trailing: Text(
        formatMoney(item.amount),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }

  String _splitLabel(BillItem item, int count) =>
      item.mode == BillSplitMode.equal
      ? 'chia đều $count người'
      : 'mỗi người một khoản';
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.transfer});

  final BillTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final mine = transfer.from == Bill.me || transfer.to == Bill.me;
    final incoming = transfer.to == Bill.me;
    final color = !mine
        ? theme.colorScheme.onSurfaceVariant
        : incoming
        ? palette.incomeText
        : palette.expenseText;
    return ListTile(
      leading: Icon(
        incoming ? Icons.call_received_rounded : Icons.call_made_rounded,
        color: color,
      ),
      title: Text(
        '${transfer.from} đưa ${transfer.to}',
        style: TextStyle(fontWeight: mine ? FontWeight.w700 : null),
      ),
      trailing: Text(
        formatMoney(transfer.amount),
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A payback already received, kept visible so a wrong one can be undone.
class _RepaidTile extends StatelessWidget {
  const _RepaidTile({
    required this.person,
    required this.amount,
    required this.onRemove,
  });

  final String person;
  final int amount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        Icons.check_circle_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text('$person đã trả bạn'),
      subtitle: Text(formatMoney(amount)),
      trailing: IconButton(
        tooltip: 'Bỏ khoản này',
        icon: const Icon(Icons.undo_rounded),
        onPressed: onRemove,
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final BillMemberTotal member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final net = member.net;
    return ListTile(
      dense: true,
      title: Text(member.person),
      subtitle: Text(
        'Đã trả ${formatMoney(member.paid)} · phần thật ${formatMoney(member.owed)}'
        '${member.paidBack > 0 ? ' · đã đưa bạn ${formatMoney(member.paidBack)}' : ''}',
      ),
      trailing: Text(
        net == 0 ? 'Hoà' : formatSigned(net.abs(), isIncome: net > 0),
        style: theme.textTheme.titleSmall?.copyWith(
          color: net == 0
              ? theme.colorScheme.onSurfaceVariant
              : net > 0
              ? palette.incomeText
              : palette.expenseText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          // Chừa đúng chiều cao của nút để dải tiêu đề không cao thấp so le.
          if (trailing != null) trailing! else const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'Bill không còn nữa',
      message: 'Có thể nó vừa bị xoá ở màn khác.',
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});

  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _field = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên bill'),
      content: TextField(
        controller: _field,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Thôi'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm người'),
      content: TextField(
        controller: _field,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Nam, chị Lan...',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Thôi'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_field.text),
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

/// Kết quả của sheet thêm/sửa một khoản.
class _ItemResult {
  const _ItemResult(this.item, {this.deleted = false});

  final BillItem item;
  final bool deleted;
}

/// Sheet ghi một khoản: ai trả, bao nhiêu, những ai cùng gánh.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.billKey, required this.members, this.item});

  final String billKey;
  final List<String> members;

  /// Có thì là sửa, không thì là thêm mới.
  final BillItem? item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final _label = TextEditingController(text: widget.item?.label ?? '');
  late final _amount = TextEditingController(
    text: widget.item == null ? '' : '${widget.item!.amount}',
  );

  /// Ô nhập số tiền của từng người, chỉ dùng ở chế độ mỗi người một khoản.
  late final Map<String, TextEditingController> _custom = {
    for (final member in widget.members)
      member: TextEditingController(text: _initialShare(member)),
  };

  late String _payer = widget.item?.payer ?? Bill.me;
  late BillSplitMode _mode = widget.item?.mode ?? BillSplitMode.equal;
  late final Set<String> _participants = {
    ...?widget.item?.people,
    if (widget.item == null) ...widget.members,
  };

  String _initialShare(String member) {
    final item = widget.item;
    if (item == null || item.mode != BillSplitMode.custom) return '';
    for (final share in item.shares) {
      if (share.person == member && (share.amount ?? 0) > 0) {
        return '${share.amount}';
      }
    }
    return '';
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    for (final controller in _custom.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _total => parseAmountInput(_amount.text) ?? 0;

  Map<String, int> get _customShares => {
    for (final entry in _custom.entries)
      if ((parseAmountInput(entry.value.text) ?? 0) > 0)
        entry.key: parseAmountInput(entry.value.text)!,
  };

  int get _assigned =>
      _customShares.values.fold(0, (sum, value) => sum + value);

  /// Phần chưa gán cho ai. Dương là còn thiếu, âm là đã gán quá tay.
  int get _leftover => _total - _assigned;

  bool get _canSave {
    if (_total <= 0) return false;
    if (_mode == BillSplitMode.equal) return _participants.isNotEmpty;
    return _leftover >= 0 && _assigned > 0;
  }

  void _save() {
    final shares = _mode == BillSplitMode.equal
        ? [
            for (final member in widget.members)
              if (_participants.contains(member)) BillShare(member),
          ]
        : [
            for (final entry in _customShares.entries)
              BillShare(entry.key, entry.value),
          ];
    final existing = widget.item;
    final item =
        existing?.copyWith(
          label: _label.text,
          amount: _total,
          payer: _payer,
          mode: _mode,
          shares: shares,
        ) ??
        BillItem.create(
          billKey: widget.billKey,
          label: _label.text,
          amount: _total,
          payer: _payer,
          mode: _mode,
          shares: shares,
        );
    Navigator.of(context).pop(_ItemResult(item));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item == null ? 'Thêm khoản' : 'Sửa khoản',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _label,
                autofocus: item == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Khoản gì',
                  hintText: 'Ăn tối, xăng xe, phòng khách sạn...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Hết bao nhiêu',
                  hintText: '1tr2, 350k, 1.200.000',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Text('Ai trả', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final member in widget.members)
                    ChoiceChip(
                      label: Text(member),
                      selected: _payer == member,
                      onSelected: (_) => setState(() => _payer = member),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<BillSplitMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in BillSplitMode.values)
                    ButtonSegment(value: mode, label: Text(mode.label)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 14),
              if (_mode == BillSplitMode.equal)
                ..._equalFields(theme)
              else
                ..._customFields(theme),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (item != null)
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_ItemResult(item, deleted: true)),
                      child: const Text('Xoá khoản'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _equalFields(ThemeData theme) {
    final count = _participants.length;
    // Chia không hết thì vài người gánh thêm một đồng lẻ, nên nói "khoảng".
    final each = count == 0 ? 0 : _total ~/ count;
    final rounded = count > 0 && _total % count != 0;
    return [
      Text('Chia cho ai', style: theme.textTheme.labelLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final member in widget.members)
            FilterChip(
              label: Text(member),
              selected: _participants.contains(member),
              onSelected: (on) => setState(() {
                if (on) {
                  _participants.add(member);
                } else {
                  _participants.remove(member);
                }
              }),
            ),
        ],
      ),
      if (_total > 0 && _participants.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          'Mỗi người ${rounded ? 'khoảng ' : ''}${formatMoney(each)} · '
          '$count người',
          style: theme.textTheme.bodySmall,
        ),
      ],
    ];
  }

  List<Widget> _customFields(ThemeData theme) {
    return [
      Text('Ai tốn bao nhiêu', style: theme.textTheme.labelLarge),
      const SizedBox(height: 4),
      for (final member in widget.members)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextField(
            controller: _custom[member],
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: member,
              hintText: 'Bỏ trống nếu người này không góp',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      if (_total > 0) ...[
        const SizedBox(height: 10),
        Text(
          _leftover > 0
              ? 'Còn ${formatMoney(_leftover)} chưa gán cho ai — '
                    'phần này $_payer tự chịu.'
              : _leftover < 0
              ? 'Đã gán quá ${formatMoney(-_leftover)} so với số tiền của khoản.'
              : 'Đã gán đủ.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _leftover < 0 ? theme.colorScheme.error : null,
          ),
        ),
      ],
    ];
  }
}
