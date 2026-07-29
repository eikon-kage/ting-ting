import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/app_theme.dart';

/// Hai nút chọn ngày kẹp một mũi tên. Đầu nào để trống là để ngỏ chứ không phải
/// chưa chọn xong, nên nhãn ghi thẳng "Từ đầu" / "Đến nay".
///
/// Dùng chung cho màn thu chi và màn tìm kiếm — hai chỗ cùng lọc theo khoảng
/// ngày, để hai kiểu khác nhau thì mắt phải học lại từ đầu.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({
    super.key,
    required this.from,
    required this.to,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onClear,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 0),
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  /// `null` khi chưa lọc ngày — nút xoá tự mờ đi.
  final VoidCallback? onClear;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: _DateButton(
              icon: Icons.event_rounded,
              label: from == null ? 'Từ đầu' : formatDay(from!),
              selected: from != null,
              onPressed: onPickStart,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded, size: 16),
          ),
          Expanded(
            child: _DateButton(
              icon: Icons.event_available_rounded,
              label: to == null ? 'Đến nay' : formatDay(to!),
              selected: to != null,
              onPressed: onPickEnd,
            ),
          ),
          IconButton(
            tooltip: 'Bỏ lọc ngày',
            icon: const Icon(Icons.close_rounded),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (selectedBg, selectedFg) = AppTheme.selectedTone(scheme);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        // Đầu đang chặn thì tô nền xám đậm và viền đậm, đầu để ngỏ thì viền mờ
        // — nhìn là biết khoảng đang mở về phía nào.
        foregroundColor: selected ? selectedFg : null,
        backgroundColor: selected ? selectedBg : null,
        side: BorderSide(
          color: selected ? scheme.outline : scheme.outlineVariant,
        ),
      ),
    );
  }
}

/// Mở lịch cho một đầu của khoảng ngày. Trả `null` khi user bấm huỷ.
Future<DateTime?> pickRangeDate(
  BuildContext context, {
  required bool isStart,
  DateTime? initial,
}) => showDatePicker(
  context: context,
  initialDate: initial ?? DateTime.now(),
  firstDate: DateTime(2015),
  // Cho tới sang năm: giao dịch ghi tay có thể đề ngày tương lai.
  lastDate: DateTime(DateTime.now().year + 1, 12, 31),
  helpText: isStart ? 'Từ ngày' : 'Đến ngày',
);
