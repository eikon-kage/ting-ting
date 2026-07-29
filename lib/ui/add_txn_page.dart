import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'controllers/add_txn_controller.dart';
import 'format.dart';
import 'widgets/category_chips.dart';

/// Nhập giao dịch bằng tay — cho tiền mặt hoặc khoản mà notification bỏ sót.
class AddTxnPage extends StatefulWidget {
  const AddTxnPage({super.key});

  @override
  State<AddTxnPage> createState() => _AddTxnPageState();
}

class _AddTxnPageState extends State<AddTxnPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _noteController = TextEditingController();
  final _accountController = TextEditingController(text: 'Tiền mặt');
  final _controller = AddTxnController();

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _noteController.dispose();
    _accountController.dispose();
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
      walletName: _accountController.text,
      description: _descController.text,
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
      appBar: AppBar(title: const Text('Thêm giao dịch')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<TxnDirection>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: TxnDirection.expense,
                    label: Text('Chi'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: TxnDirection.income,
                    label: Text('Thu'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {_controller.direction},
                onSelectionChanged: (selection) =>
                    _controller.selectDirection(selection.first),
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
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  hintText: 'Ăn trưa, gửi xe...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Tiền ra/vào ví nào', style: theme.textTheme.labelLarge),
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
              const SizedBox(height: 16),
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
              Text('Nhóm', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              CategoryChips(
                selected: _controller.category,
                onSelected: _controller.selectCategory,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _controller.saving ? null : _save,
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
