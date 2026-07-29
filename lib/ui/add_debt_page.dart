import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'controllers/debt_controller.dart';
import 'format.dart';

/// Ghi thẳng một khoản cho vay / đi vay / thu nợ / trả nợ.
///
/// Khác với [showAssignDebtSheet] — cái đó gán một giao dịch đã có vào sổ nợ.
/// Ở đây khoản nợ được tạo mới hoàn toàn, dùng cho tiền mặt đưa tay hoặc
/// khoản mà ngân hàng không bắn thông báo.
class AddDebtPage extends StatefulWidget {
  const AddDebtPage({super.key, this.person, this.initialType});

  /// Điền sẵn tên người — dùng khi mở từ trang chi tiết của một người.
  final String? person;

  final DebtType? initialType;

  @override
  State<AddDebtPage> createState() => _AddDebtPageState();
}

class _AddDebtPageState extends State<AddDebtPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _accountController = TextEditingController(text: 'Tiền mặt');
  late final _personController = TextEditingController(
    text: widget.person ?? '',
  );
  late final _controller = AddDebtController(initialType: widget.initialType);

  @override
  void initState() {
    super.initState();
    _controller.init();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _accountController.dispose();
    _personController.dispose();
    _controller.dispose();
    super.dispose();
  }

  int get _amount => parseAmount(_amountController.text);

  Future<void> _pickDateTime() async {
    final when = _controller.when;
    final date = await showDatePicker(
      context: context,
      initialDate: when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(when),
    );
    if (!mounted) return;
    _controller.selectWhen(
      DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? when.hour,
        time?.minute ?? when.minute,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await _controller.save(
      amount: _amount,
      person: _personController.text,
      walletName: _accountController.text,
      note: _noteController.text,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  /// Đổi ví thì tên ví nhảy theo, trừ khi user đã tự đặt tên riêng.
  void _selectAccountKind(AccountKind kind) {
    if (_accountController.text.trim() == _controller.accountKind.label) {
      _accountController.text = kind.label;
    }
    _controller.selectAccountKind(kind);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ghi khoản nợ')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isOut = _controller.isOutgoing;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Loại khoản', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final type in DebtType.values)
                      ChoiceChip(
                        label: Text(type.label),
                        selected: _controller.type == type,
                        onSelected: (_) => _controller.selectType(type),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_controller.type.hint} · '
                  '${isOut ? 'tiền ra khỏi ví' : 'tiền vào ví'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền',
                    suffixText: 'đ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (_) => _amount <= 0 ? 'Nhập số tiền' : null,
                  onChanged: (_) => setState(() {}),
                ),
                if (_amount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      formatMoney(_amount),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _personController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Với ai',
                    hintText: 'Bố mẹ, Nam, chị Lan...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Nhập tên người' : null,
                ),
                if (_controller.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final name in _controller.suggestions.take(6))
                        ActionChip(
                          label: Text(name),
                          onPressed: () => _personController.text = name,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  isOut ? 'Tiền ra từ ví nào' : 'Tiền vào ví nào',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<AccountKind>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AccountKind.cash,
                      label: Text('Tiền mặt'),
                      icon: Icon(Icons.payments_rounded),
                    ),
                    ButtonSegment(
                      value: AccountKind.bank,
                      label: Text('Tài khoản'),
                      icon: Icon(Icons.account_balance_outlined),
                    ),
                  ],
                  selected: {_controller.accountKind},
                  onSelectionChanged: (selection) =>
                      _selectAccountKind(selection.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _accountController,
                  decoration: InputDecoration(
                    labelText: 'Tên ví',
                    hintText: _controller.accountKind == AccountKind.bank
                        ? 'Vietcombank, MoMo...'
                        : 'Ví, két...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: const Text('Thời điểm'),
                  subtitle: Text(
                    '${formatDay(_controller.when)} ${formatTime(_controller.when)}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickDateTime,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    hintText: 'Hẹn trả cuối tháng...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Khoản nợ không được tính vào Thu–Chi, nhưng vẫn làm thay đổi '
                  'số dư ví như một giao dịch bình thường.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _controller.saving ? null : _save,
                  child: const Text('Lưu'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
