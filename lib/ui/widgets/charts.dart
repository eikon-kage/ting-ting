import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';

/// Một lát của biểu đồ tròn.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Biểu đồ tròn có lỗ giữa, dùng cho tỷ trọng chi theo nhóm.
///
/// Chạm vào một lát để xem chi tiết ở giữa. Các lát cách nhau 2px màu nền để
/// hai màu cạnh nhau không dính vào nhau — người khó phân biệt màu vẫn thấy
/// được ranh giới.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 180,
  });

  final List<DonutSlice> slices;
  final double size;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _selected;

  int get _total => widget.slices.fold(0, (sum, s) => sum + s.value);

  /// Đổi toạ độ chạm thành chỉ số lát.
  void _handleTap(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final offset = local - center;
    final distance = offset.distance;
    final outer = widget.size / 2;
    final inner = outer * _DonutPainter.innerRatio;
    if (distance > outer || distance < inner) {
      setState(() => _selected = null);
      return;
    }
    // atan2 tính từ trục x; biểu đồ bắt đầu từ 12 giờ nên xoay lại 90 độ.
    var angle = math.atan2(offset.dy, offset.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final total = _total;
    if (total == 0) return;
    var sweep = 0.0;
    for (var i = 0; i < widget.slices.length; i++) {
      sweep += widget.slices[i].value / total * 2 * math.pi;
      if (angle <= sweep) {
        setState(() => _selected = _selected == i ? null : i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total;
    final selected = _selected != null && _selected! < widget.slices.length
        ? widget.slices[_selected!]
        : null;
    return GestureDetector(
      onTapDown: (details) => _handleTap(details.localPosition),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _DonutPainter(
            slices: widget.slices,
            total: total,
            selected: _selected,
            gapColor: theme.colorScheme.surface,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected?.label ?? 'Tổng chi',
                  style: theme.textTheme.labelMedium,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formatCompact(selected?.value ?? total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (selected != null && total > 0)
                  Text(
                    '${(selected.value / total * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.selected,
    required this.gapColor,
  });

  static const double innerRatio = 0.62;

  final List<DonutSlice> slices;
  final int total;
  final int? selected;
  final Color gapColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    final outer = size.width / 2;
    final thickness = outer * (1 - innerRatio);
    final radius = outer - thickness / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Khoảng hở 2px giữa các lát, quy đổi ra góc theo bán kính.
    final gap = slices.length > 1 ? 2 / radius : 0.0;
    var start = -math.pi / 2;

    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].value / total * 2 * math.pi;
      if (sweep <= 0) continue;
      final isSelected = selected == i;
      final paint = Paint()
        ..color = slices[i].color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? thickness + 4 : thickness;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, gap / 2),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.selected != selected || old.total != total;
}

/// Một tháng trên biểu đồ cột.
class MonthBars {
  const MonthBars({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final int income;
  final int expense;
}

/// Biểu đồ cột kép thu/chi theo tháng.
///
/// Chỉ dán nhãn số lên cột đang chọn và cột tháng cuối — dán hết thì rối và
/// chẳng ai đọc. Chạm vào cột để xem số của tháng đó.
class GroupedBarChart extends StatefulWidget {
  const GroupedBarChart({
    super.key,
    required this.months,
    required this.incomeColor,
    required this.expenseColor,
    this.height = 160,
  });

  final List<MonthBars> months;
  final Color incomeColor;
  final Color expenseColor;
  final double height;

  @override
  State<GroupedBarChart> createState() => _GroupedBarChartState();
}

class _GroupedBarChartState extends State<GroupedBarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = widget.months.fold<int>(
      0,
      (m, e) => math.max(m, math.max(e.income, e.expense)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / widget.months.length;
        return GestureDetector(
          onTapDown: (details) {
            final index = (details.localPosition.dx / slotWidth).floor();
            setState(() {
              _selected =
                  (index >= 0 && index < widget.months.length && _selected != index)
                  ? index
                  : null;
            });
          },
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarPainter(
                months: widget.months,
                maxValue: max,
                selected: _selected,
                incomeColor: widget.incomeColor,
                expenseColor: widget.expenseColor,
                gridColor: theme.colorScheme.outlineVariant,
                labelStyle:
                    theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12),
                valueStyle:
                    theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.months,
    required this.maxValue,
    required this.selected,
    required this.incomeColor,
    required this.expenseColor,
    required this.gridColor,
    required this.labelStyle,
    required this.valueStyle,
  });

  final List<MonthBars> months;
  final int maxValue;
  final int? selected;
  final Color incomeColor;
  final Color expenseColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  static const double _axisHeight = 18;
  static const double _valueLabelHeight = 14;
  static const double _barGap = 2;
  static const double _radius = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty || maxValue <= 0) return;
    final plotTop = _valueLabelHeight;
    final plotBottom = size.height - _axisHeight;
    final plotHeight = plotBottom - plotTop;
    final slotWidth = size.width / months.length;
    final barWidth = math.min((slotWidth - 12 - _barGap) / 2, 18.0);

    // Đường chân trục, mảnh và nhạt để không tranh chấp với cột.
    canvas.drawLine(
      Offset(0, plotBottom),
      Offset(size.width, plotBottom),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    for (var i = 0; i < months.length; i++) {
      final month = months[i];
      final centerX = slotWidth * i + slotWidth / 2;
      final incomeRect = _barRect(
        centerX - barWidth - _barGap / 2,
        barWidth,
        month.income,
        plotBottom,
        plotHeight,
      );
      final expenseRect = _barRect(
        centerX + _barGap / 2,
        barWidth,
        month.expense,
        plotBottom,
        plotHeight,
      );
      _drawBar(canvas, incomeRect, incomeColor);
      _drawBar(canvas, expenseRect, expenseColor);

      _drawText(
        canvas,
        month.label,
        Offset(centerX, plotBottom + 3),
        labelStyle,
        center: true,
      );

      // Nhãn số chỉ ở tháng cuối hoặc tháng đang được chọn.
      final labelled = selected == null ? i == months.length - 1 : selected == i;
      if (labelled) {
        _drawText(
          canvas,
          formatCompact(month.income),
          Offset(incomeRect.center.dx, plotTop - _valueLabelHeight + 1),
          valueStyle.copyWith(color: incomeColor),
          center: true,
        );
        _drawText(
          canvas,
          formatCompact(month.expense),
          Offset(expenseRect.center.dx, plotTop - _valueLabelHeight + 1),
          valueStyle.copyWith(color: expenseColor),
          center: true,
        );
      }
    }
  }

  Rect _barRect(
    double left,
    double width,
    int value,
    double bottom,
    double plotHeight,
  ) {
    final height = value <= 0 ? 0.0 : value / maxValue * plotHeight;
    return Rect.fromLTWH(left, bottom - height, width, height);
  }

  /// Cột bo tròn ở đầu mút dữ liệu, vuông ở chân để bám vào trục.
  void _drawBar(Canvas canvas, Rect rect, Color color) {
    if (rect.height <= 0) return;
    final radius = math.min(_radius, rect.height);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      ),
      Paint()..color = color,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center ? position.translate(-painter.width / 2, 0) : position,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.months != months ||
      old.selected != selected ||
      old.maxValue != maxValue;
}

/// Chú giải cho biểu đồ — luôn có khi từ 2 chuỗi trở lên, để danh tính không
/// chỉ nằm ở màu.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});

  final List<({String label, Color color})> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: entry.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(entry.label, style: theme.textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
