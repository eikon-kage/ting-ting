import 'package:flutter/material.dart';

import '../models/models.dart';
import 'controllers/digest_controller.dart';
import 'format.dart';
import 'widgets/empty_state.dart';

/// Nhìn lại: tuần vừa rồi (hoặc tháng này) có gì khác trước.
///
/// Màn Báo cáo nói tiền đi đâu; màn này nói cái gì đã đổi. Một biểu đồ tròn
/// không cho biết tự dưng tháng này đi lại tốn gấp đôi — mà đó mới là thứ
/// khiến người ta đổi cách tiêu.
class DigestPage extends StatefulWidget {
  const DigestPage({super.key});

  @override
  State<DigestPage> createState() => _DigestPageState();
}

class _DigestPageState extends State<DigestPage> {
  final _controller = DigestController();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Nhìn lại')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final digest = _controller.digest;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _PeriodTabs(
                selected: _controller.period,
                onSelect: _controller.selectPeriod,
              ),
              if (_controller.loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (digest == null || digest.isEmpty)
                const _NoDigest()
              else ...[
                _HeadlineCard(digest: digest),
                _RhythmCard(digest: digest),
                if (digest.biggestRise case final rise?)
                  _ShiftCard(shift: rise, rising: true),
                if (digest.biggestDrop case final drop?)
                  _ShiftCard(shift: drop, rising: false),
                if (digest.biggest case final biggest?)
                  _BiggestCard(txn: biggest),
              ],
              if (_controller.remindersSupported)
                SwitchListTile(
                  value: _controller.reminderOn,
                  onChanged: (value) =>
                      _controller.setReminder(enabled: value),
                  secondary: const Icon(Icons.alarm_rounded),
                  title: const Text('Nhắc sáng thứ Hai'),
                  subtitle: const Text(
                    'Một thông báo đầu tuần để mở lại màn này',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelect});

  final DigestPeriod selected;
  final ValueChanged<DigestPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<DigestPeriod>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: DigestPeriod.week, label: Text('Tuần này')),
          ButtonSegment(value: DigestPeriod.month, label: Text('Tháng này')),
        ],
        selected: {selected},
        onSelectionChanged: (values) => onSelect(values.first),
      ),
    );
  }
}

/// Câu chốt: tiêu bao nhiêu, hơn hay kém kỳ trước.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.digest});

  final Digest digest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final diff = digest.diff;
    final percent = digest.percent;
    final more = diff > 0;

    final String comparison;
    if (digest.previousSpent == 0) {
      comparison = '${digest.period.pastLabel.capitalize()} chưa có gì để so.';
    } else if (diff == 0) {
      comparison = 'Bằng đúng ${digest.period.pastLabel}.';
    } else {
      final amount = formatMoney(diff.abs());
      final share = percent == null ? '' : ' (${percent.abs()}%)';
      comparison = more
          ? 'Nhiều hơn ${digest.period.pastLabel} $amount$share.'
          : 'Ít hơn ${digest.period.pastLabel} $amount$share.';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đã chi ${digest.daysCovered} ngày qua',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(digest.spent),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(comparison, style: theme.textTheme.bodyMedium),
            if (digest.income > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Thu vào ${formatMoney(digest.income)}, '
                'còn lại ${formatMoney(digest.net)}.',
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

/// Nhịp tiêu: mỗi ngày bao nhiêu, ngày nào nặng nhất, mấy ngày không tiêu gì.
class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.digest});

  final Digest digest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhịp tiêu',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _Line(
              icon: Icons.speed_rounded,
              text:
                  'Trung bình ${formatMoney(digest.dailyRate)}/ngày, '
                  '${digest.txnCount} giao dịch.',
            ),
            if (digest.busiestDay case final day?)
              _Line(
                icon: Icons.local_fire_department_rounded,
                text:
                    'Nặng nhất là ${formatDayHeader(day.day).toLowerCase()} — '
                    '${formatMoney(day.total)}.',
              ),
            _Line(
              icon: Icons.self_improvement_rounded,
              text: digest.noSpendDays == 0
                  ? 'Không có ngày nào không tiêu gì.'
                  : '${digest.noSpendDays} ngày không tiêu đồng nào.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhóm đổi mạnh nhất — thứ đáng nói nhất trong một bản tổng kết.
class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.rising});

  final CategoryShift shift;
  final bool rising;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = rising ? scheme.error : scheme.primary;

    final String detail;
    if (shift.isNew) {
      detail = 'Kỳ trước không tiêu đồng nào cho nhóm này.';
    } else if (shift.percent case final percent?) {
      detail =
          '${formatMoney(shift.before)} → ${formatMoney(shift.now)} '
          '(${percent > 0 ? '+' : ''}$percent%).';
    } else {
      detail = '${formatMoney(shift.before)} → ${formatMoney(shift.now)}.';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        leading: Icon(
          // Trend glyph, not a plain arrow: straight arrows now mean thu/chi
          // everywhere else, and this row is about tăng/giảm.
          rising ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: color,
        ),
        title: Text(
          rising
              ? '${shift.category} tăng ${formatMoney(shift.diff)}'
              : '${shift.category} giảm ${formatMoney(-shift.diff)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(detail),
      ),
    );
  }
}

class _BiggestCard extends StatelessWidget {
  const _BiggestCard({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = txn.description?.trim();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_long_rounded),
        title: Text(
          'Khoản lớn nhất: ${formatMoney(txn.amount)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${label == null || label.isEmpty ? txn.category : label} · '
          '${formatDay(txn.postTime)}',
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _NoDigest extends StatelessWidget {
  const _NoDigest();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.history_toggle_off_rounded,
      title: 'Kỳ này chưa có khoản chi nào',
      message:
          'Bản tổng kết so kỳ này với kỳ trước để chỉ ra chỗ đổi khác. Cần ít '
          'nhất một khoản chi mới có gì để nói.',
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
