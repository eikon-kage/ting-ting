import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'controllers/edit_balance_controller.dart';
import 'format.dart';

/// Sửa số tiền đang có của một ví.
///
/// [walletName] để `null` khi ví chưa tồn tại — sheet sẽ hỏi tên. Trả về `true`
/// nếu có ghi khoản chênh lệch.
Future<bool> showEditBalanceSheet(
  BuildContext context, {
  required AccountKind accountKind,
  required int current,
  String? walletName,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditBalanceSheet(
      accountKind: accountKind,
      current: current,
      walletName: walletName,
    ),
  );
  return saved ?? false;
}

class _EditBalanceSheet extends StatefulWidget {
  const _EditBalanceSheet({
    required this.accountKind,
    required this.current,
    required this.walletName,
  });

  final AccountKind accountKind;
  final int current;
  final String? walletName;

  @override
  State<_EditBalanceSheet> createState() => _EditBalanceSheetState();
}

class _EditBalanceSheetState extends State<_EditBalanceSheet> {
  late final _amount = TextEditingController(
    text: widget.current > 0 ? widget.current.toString() : '',
  );
  late final _name = TextEditingController(
    text: widget.walletName ?? widget.accountKind.label,
  );
  late final _controller = EditBalanceController(
    accountKind: widget.accountKind,
    current: widget.current,
  );

  /// Ví đã có sẵn thì tên là dữ liệu, không cho sửa ở đây.
  bool get _asksForName => widget.walletName == null;

  int get _target => parseAmount(_amount.text);
  int get _delta => _controller.deltaTo(_target);

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await _controller.save(
      target: _target,
      walletName: _name.text,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.walletName ?? widget.accountKind.label;
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
              Text('Sửa số tiền đang có', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '$label · đang là ${formatMoney(widget.current)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (_asksForName) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Tên ví',
                    hintText: widget.accountKind == AccountKind.bank
                        ? 'Vietcombank, MoMo...'
                        : 'Ví, két...',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: theme.textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thực tế',
                  suffixText: 'đ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _delta == 0 ? null : _save(),
              ),
              const SizedBox(height: 10),
              _DeltaHint(delta: _delta, target: _target),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _controller.saving || _delta == 0 ? null : _save,
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nói trước app sắp ghi thêm khoản gì — user thấy số dư nhảy mà không hiểu
/// vì sao thì còn khó chịu hơn là không sửa được.
class _DeltaHint extends StatelessWidget {
  const _DeltaHint({required this.delta, required this.target});

  final int delta;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = delta == 0
        ? 'Bằng đúng số đang có, chưa cần sửa.'
        : 'Ghi thêm một khoản ${formatSigned(delta.abs(), isIncome: delta > 0)} '
              'để số dư thành ${formatMoney(target)}. Khoản này không tính vào '
              'thu chi của tháng.';
    return Text(text, style: theme.textTheme.bodySmall);
  }
}
