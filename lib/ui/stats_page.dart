import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/data_store.dart';
import '../models/models.dart';
import 'controllers/stats_controller.dart';
import 'format.dart';
import 'theme/chart_palette.dart';
import 'widgets/charts.dart';
import 'widgets/month_selector.dart';

/// Báo cáo: chi theo nhóm, xu hướng 6 tháng, nơi tiêu nhiều nhất,
/// và so với tháng trước.
///
/// Là một tab trong [RootShell], nên tháng xem được giữ nguyên khi rời tab rồi
/// quay lại — đang soi tháng 3 mà nhảy sang tab khác không bị kéo về tháng này.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, this.month, this.reloadSignal});

  /// Tháng mở đầu; bỏ trống là tháng hiện tại.
  final DateTime? month;

  /// Bắn ra từ [RootShell] khi tab này được chọn lại, để nạp lại số liệu.
  final ValueListenable<int>? reloadSignal;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late final _controller = StatsController(month: widget.month);

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

  /// Gộp các nhóm nhỏ lại thành "Khác" — bảng màu chỉ đủ cho 6 nhóm, và quá
  /// nhiều lát thì biểu đồ cũng không đọc được nữa.
  static List<DonutSlice> _slices(
    List<CategoryTotal> byCategory,
    ChartPalette palette,
  ) {
    final slices = <DonutSlice>[];
    final visible = byCategory.take(palette.maxSlots - 1).toList();
    for (var i = 0; i < visible.length; i++) {
      slices.add(
        DonutSlice(
          label: visible[i].category,
          value: visible[i].total,
          color: palette.series(i),
        ),
      );
    }
    final rest = byCategory.skip(visible.length);
    if (rest.isNotEmpty) {
      slices.add(
        DonutSlice(
          label: 'Khác',
          value: rest.fold(0, (sum, e) => sum + e.total),
          color: palette.other,
        ),
      );
    }
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final report = _controller.report;
          final slices = _slices(report.byCategory, palette);
          final totalExpense = report.totalExpense;
          final diff = report.expenseDiff;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              MonthSelector(
                month: _controller.month,
                onPrev: () => _controller.shiftMonth(-1),
                onNext: _controller.showingCurrentMonth
                    ? null
                    : () => _controller.shiftMonth(1),
              ),
              if (report.forecast case final forecast?
                  when !forecast.isComplete && forecast.reliable)
                _ForecastCard(forecast: forecast, palette: palette),
              if (diff != null)
                _ComparisonCard(
                  diff: diff,
                  lastExpense: report.previous!.expense,
                  palette: palette,
                ),
              _Section(
                title: 'Chi theo nhóm',
                child: totalExpense == 0
                    ? const _NoData()
                    : Column(
                        children: [
                          Center(child: DonutChart(slices: slices)),
                          const SizedBox(height: 16),
                          // Danh sách này vừa là chú giải vừa là bảng số —
                          // đọc được đầy đủ kể cả khi không phân biệt màu.
                          for (final slice in slices)
                            _LegendRow(
                              slice: slice,
                              share: slice.value / totalExpense,
                            ),
                        ],
                      ),
              ),
              _Section(
                title:
                    'Thu chi ${ReportRepository.defaultTrendMonths} tháng gần nhất',
                child: report.trend.isEmpty
                    ? const _NoData()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChartLegend(
                            entries: [
                              (label: 'Thu', color: palette.incomeMark),
                              (label: 'Chi', color: palette.expenseMark),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GroupedBarChart(
                            months: [
                              for (final entry in report.trend)
                                MonthBars(
                                  label: formatMonthShort(entry.month),
                                  income: entry.income,
                                  expense: entry.expense,
                                ),
                            ],
                            incomeColor: palette.incomeMark,
                            expenseColor: palette.expenseMark,
                          ),
                        ],
                      ),
              ),
              _Section(
                title: 'Tiêu nhiều nhất',
                child: report.topSpending.isEmpty
                    ? const _NoData()
                    : Column(
                        children: [
                          for (final entry in report.topSpending)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                entry.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('${entry.count} lần'),
                              trailing: Text(
                                formatMoney(entry.total),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tháng này đang đi về đâu, đặt ngay đầu màn báo cáo.
///
/// Cố tình đứng trước phần so với tháng trước: lúc còn nửa tháng, biết mình
/// sắp về đâu thì còn kịp đổi, còn số của tháng trước thì chỉ để tham chiếu.
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.palette});

  final MonthForecast forecast;
  final ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final diff = forecast.diffVsPrevious;
    final overspending = diff != null && diff > 0;
    final color = diff == null
        ? scheme.primary
        : overspending
        ? palette.expenseText
        : palette.incomeText;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_rounded, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  'Giữ nhịp này, cuối tháng',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '≈ ${formatMoney(forecast.projected)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đã chi ${formatMoney(forecast.spent)} trong '
              '${forecast.daysElapsed} ngày — trung bình '
              '${formatMoney(forecast.dailyRate)}/ngày, còn '
              '${forecast.daysLeft} ngày nữa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (diff != null) ...[
              const SizedBox(height: 10),
              Text(
                overspending
                    ? 'Nhiều hơn tháng trước ${formatMoney(diff)}.'
                    : 'Ít hơn tháng trước ${formatMoney(-diff)}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (forecast.dailyBudgetLeft case final perDay?)
                Text(
                  perDay >= 0
                      ? 'Tiêu dưới ${formatMoney(perDay)}/ngày thì vẫn bằng '
                            'tháng trước.'
                      : 'Đã vượt mức tháng trước, không còn dư ngày nào.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.diff,
    required this.lastExpense,
    required this.palette,
  });

  /// Chi tháng này trừ chi tháng trước; dương là tiêu nhiều hơn.
  final int diff;

  final int lastExpense;
  final ChartPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = lastExpense == 0 ? null : (diff / lastExpense * 100).round();
    final spendingMore = diff > 0;
    final color = spendingMore ? palette.expenseText : palette.incomeText;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            spendingMore
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 22,
            color: color,
          ),
        ),
        title: Text(
          diff == 0
              ? 'Tiêu bằng tháng trước'
              : spendingMore
              ? 'Tiêu nhiều hơn tháng trước ${formatMoney(diff)}'
              : 'Tiêu ít hơn tháng trước ${formatMoney(-diff)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: percent == null
            ? null
            : Text('${percent.abs()}% so với ${formatMoney(lastExpense)}'),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.share});

  final DonutSlice slice;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: slice.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${(share * 100).round()}%',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(width: 12),
          Text(
            formatMoney(slice.value),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Chưa có dữ liệu',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
