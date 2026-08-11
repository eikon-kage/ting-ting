import 'package:flutter/material.dart';

import '../domain/bill_split.dart';
import '../models/models.dart';
import 'bill_page.dart';
import 'controllers/bill_controller.dart';
import 'format.dart';
import 'theme/chart_palette.dart';
import 'widgets/empty_state.dart';

/// Danh sách các cuộc chia tiền chung.
///
/// Chia bill đứng ngoài Thu–Chi lẫn Sổ nợ: tiền thật ra khỏi ví lúc nào thì
/// thông báo ngân hàng đã ghi rồi, ở đây chỉ tính xem cuối cùng ai đưa ai
/// bao nhiêu.
class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  final _controller = BillsController();

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

  Future<void> _create() async {
    final created = await showModalBottomSheet<_NewBill>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NewBillSheet(suggestions: _controller.suggestions),
    );
    if (created == null || !mounted) return;
    final bill = await _controller.create(
      title: created.title,
      members: created.members,
    );
    if (!mounted) return;
    await _open(bill.key);
  }

  Future<void> _open(String billKey) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => BillPage(billKey: billKey)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chia bill')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Bill mới'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final bills = _controller.bills;
          if (bills.isEmpty) return const _EmptyBills();
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: ListView(
              children: [
                _Standing(
                  toMe: _controller.owedToMe,
                  byMe: _controller.owedByMe,
                ),
                for (final entry in bills)
                  _BillTile(entry: entry, onTap: () => _open(entry.bill.key)),
                const SizedBox(height: 88),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tổng của mọi bill chưa tất toán.
class _Standing extends StatelessWidget {
  const _Standing({required this.toMe, required this.byMe});

  final int toMe;
  final int byMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    if (toMe == 0 && byMe == 0) return const SizedBox(height: 8);
    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: _Amount(
                label: 'Được nhận về',
                value: toMe,
                color: palette.incomeText,
              ),
            ),
            Expanded(
              child: _Amount(
                label: 'Còn phải đưa',
                value: byMe,
                color: palette.expenseText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(value),
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

class _BillTile extends StatelessWidget {
  const _BillTile({required this.entry, required this.onTap});

  final BillOverview entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final bill = entry.bill;
    final net = entry.settlement.myNet;
    final settled = bill.settled;
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: settled
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          settled ? Icons.check_rounded : Icons.receipt_long_rounded,
          size: 22,
          color: settled
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        bill.title,
        style: TextStyle(
          decoration: settled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${bill.members.length} người · ${formatMoney(entry.settlement.total)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: settled || net == 0
          ? Text(
              settled ? 'Đã xong' : 'Hoà',
              style: theme.textTheme.labelMedium,
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  net > 0 ? 'Được nhận' : 'Phải đưa',
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  formatMoney(net.abs()),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: net > 0 ? palette.incomeText : palette.expenseText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
      onTap: onTap,
    );
  }
}

/// Tên và danh sách người của một bill sắp tạo.
class _NewBill {
  const _NewBill(this.title, this.members);

  final String title;
  final List<String> members;
}

class _NewBillSheet extends StatefulWidget {
  const _NewBillSheet({required this.suggestions});

  final List<String> suggestions;

  @override
  State<_NewBillSheet> createState() => _NewBillSheetState();
}

class _NewBillSheetState extends State<_NewBillSheet> {
  final _title = TextEditingController();
  final _person = TextEditingController();
  final _members = <String>[];

  @override
  void dispose() {
    _title.dispose();
    _person.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final merged = Bill.mergeMembers(_members, [raw]);
    setState(() {
      _members
        ..clear()
        ..addAll(merged);
      _person.clear();
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    // Tên còn nằm trong ô nhập cũng tính — không ai nghĩ mình phải bấm Enter
    // lần nữa trước khi bấm Tạo.
    final members = Bill.mergeMembers(_members, [_person.text]);
    Navigator.of(context).pop(_NewBill(title, members));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unused = [
      for (final name in widget.suggestions)
        if (!_members.any((m) => m.toLowerCase() == name.toLowerCase())) name,
    ];
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
              Text('Bill mới', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Cuộc này là gì',
                  hintText: 'Đi Đà Lạt, lẩu tối qua...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _person,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Đi cùng ai',
                  hintText: 'Gõ tên rồi bấm Enter',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Thêm người',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => _add(_person.text),
                  ),
                ),
                onSubmitted: _add,
              ),
              if (_members.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final name in _members)
                      InputChip(
                        label: Text(name),
                        onDeleted: () => setState(() => _members.remove(name)),
                      ),
                  ],
                ),
              ],
              if (unused.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Đã đi cùng trước đây',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final name in unused.take(8))
                      ActionChip(
                        label: Text(name),
                        onPressed: () => _add(name),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Bạn luôn có mặt trong bill, khỏi tự thêm tên mình.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _title.text.trim().isEmpty ? null : _submit,
                  child: const Text('Tạo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  const _EmptyBills();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.receipt_long_rounded,
      title: 'Chưa có bill nào',
      message:
          'Bấm "Bill mới" cho một chuyến đi chơi hay một bữa ăn chung, ghi từng '
          'khoản ai đã trả, app tính ra cuối cùng ai đưa ai bao nhiêu.',
    );
  }
}
