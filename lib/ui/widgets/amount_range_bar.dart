import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';

/// Hai ô nhập số tiền kẹp một mũi tên — cùng khuôn với [DateRangeBar] ngay
/// phía trên nó, để mắt không phải học hai kiểu lọc khác nhau.
///
/// Hiểu lối viết tắt "500k", "1,5tr"; số đọc ra được in ngay dưới ô để user
/// thấy mình vừa gõ ra con số nào trước khi kết quả đổi.
class AmountRangeBar extends StatefulWidget {
  const AmountRangeBar({
    super.key,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onClear,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 0),
  });

  final int? min;
  final int? max;

  /// Bắn ra mỗi lần gõ; `null` ở đầu nào là để ngỏ đầu đó.
  final void Function({int? min, int? max}) onChanged;

  /// `null` khi chưa lọc tiền — nút xoá tự mờ đi.
  final VoidCallback? onClear;

  final EdgeInsetsGeometry padding;

  @override
  State<AmountRangeBar> createState() => _AmountRangeBarState();
}

class _AmountRangeBarState extends State<AmountRangeBar> {
  final _minText = TextEditingController();
  final _maxText = TextEditingController();

  @override
  void didUpdateWidget(AmountRangeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bấm nút xoá thì hai ô phải trống theo. Chỉ đụng vào ô khi chữ trong đó
    // không còn khớp với giá trị bên ngoài — không thì con trỏ nhảy về đầu
    // ngay giữa lúc user đang gõ.
    if (widget.min == null && parseAmountInput(_minText.text) != null) {
      _minText.clear();
    }
    if (widget.max == null && parseAmountInput(_maxText.text) != null) {
      _maxText.clear();
    }
  }

  @override
  void dispose() {
    _minText.dispose();
    _maxText.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
    min: parseAmountInput(_minText.text),
    max: parseAmountInput(_maxText.text),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _AmountField(
              controller: _minText,
              hint: 'Từ 0 đ',
              value: widget.min,
              onChanged: (_) => _emit(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 14, 6, 0),
            child: Icon(Icons.arrow_forward_rounded, size: 16),
          ),
          Expanded(
            child: _AmountField(
              controller: _maxText,
              hint: 'Không giới hạn',
              value: widget.max,
              onChanged: (_) => _emit(),
            ),
          ),
          IconButton(
            tooltip: 'Bỏ lọc tiền',
            icon: const Icon(Icons.close_rounded),
            onPressed: widget.onClear,
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Chỉ những ký tự [parseAmountInput] đọc được, khỏi phải báo lỗi.
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,ktrmKTRM ]')),
      ],
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.payments_outlined, size: 18),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        hintText: hint,
        hintStyle: theme.textTheme.bodySmall,
        // In lại con số đọc được: gõ "1,5tr" thì thấy ngay "1.500.000 đ".
        helperText: value == null ? ' ' : formatMoney(value!),
        helperStyle: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}
