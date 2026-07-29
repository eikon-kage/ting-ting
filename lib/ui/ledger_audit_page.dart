import 'package:flutter/material.dart';

import '../models/models.dart';
import 'controllers/ledger_audit_controller.dart';
import 'format.dart';
import 'widgets/empty_state.dart';

/// Kiểm sổ: đối chiếu số dư ngân hàng báo với số dư sổ tự cộng ra.
///
/// App ghi sổ bằng thông báo, mà thông báo thì có thể mất. Màn này là chỗ duy
/// nhất trả lời được câu "sổ của mình có còn đúng không" — và khi lệch thì nói
/// luôn thiếu bao nhiêu, trong khoảng nào.
class LedgerAuditPage extends StatefulWidget {
  const LedgerAuditPage({super.key});

  @override
  State<LedgerAuditPage> createState() => _LedgerAuditPageState();
}

class _LedgerAuditPageState extends State<LedgerAuditPage> {
  final _controller = LedgerAuditController();

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

  Future<void> _fill(LedgerGap gap) async {
    await _controller.fill(gap);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã ghi khoản bù — mở giao dịch để đặt lại nhóm'),
      ),
    );
  }

  Future<void> _fillAll() async {
    final count = _controller.audit.gapCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bù hết?'),
        content: Text(
          'Ghi $count giao dịch bù để sổ khớp với số dư ngân hàng. '
          'Mỗi khoản đều được đánh dấu "cần xem lại" để bạn đặt lại nhóm sau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bù hết'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _controller.fillAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm sổ'),
        actions: [
          IconButton(
            tooltip: 'Kiểm lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _controller.refresh,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final audit = _controller.audit;
          if (audit.hasNothingToCheck) return const _NothingToCheck();

          final suspicious = audit.suspicious;
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              _Verdict(audit: audit),
              for (final bank in suspicious) ...[
                _BankHeader(bank: bank),
                for (final gap in bank.gaps)
                  _GapTile(
                    gap: gap,
                    busy: _controller.isFilling(gap),
                    onFill: () => _fill(gap),
                  ),
              ],
              for (final bank in audit.unreliable) _UnreliableNotice(bank: bank),
              if (audit.unverifiable.isNotEmpty)
                _BlindSpotNotice(banks: audit.unverifiable),
            ],
          );
        },
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _controller.audit.gapCount < 2
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _fillAll,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Bù hết'),
              ),
      ),
    );
  }
}

/// Câu trả lời gọn cho "sổ có đúng không", đặt trên cùng.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.audit});

  final LedgerAudit audit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (audit.isClean) {
      return NoticeBanner(
        icon: Icons.verified_rounded,
        title: 'Sổ khớp với ngân hàng',
        message:
            'Đã đối chiếu ${audit.checked} giao dịch, không thiếu khoản nào.',
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      );
    }
    if (audit.gapCount == 0) {
      return NoticeBanner(
        icon: Icons.help_outline_rounded,
        title: 'Chưa kết luận được',
        message:
            'Không đủ dữ liệu số dư liền mạch để đối chiếu. Dùng thêm ít hôm '
            'rồi kiểm lại.',
      );
    }
    final net = audit.netMissing;
    return NoticeBanner(
      icon: Icons.report_gmailerrorred_rounded,
      title: 'Thiếu ${audit.gapCount} giao dịch',
      message:
          'Số dư ngân hàng báo không khớp với sổ. Chênh lệch ròng '
          '${formatSigned(net.abs(), isIncome: net > 0)} — đây là những khoản '
          'đã xảy ra thật nhưng app không nhận được thông báo.',
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
    );
  }
}

class _BankHeader extends StatelessWidget {
  const _BankHeader({required this.bank});

  final BankLedger bank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (bank.missingOut > 0) 'thiếu chi ${formatMoney(bank.missingOut)}',
      if (bank.missingIn > 0) 'thiếu thu ${formatMoney(bank.missingIn)}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bank.bankName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            parts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một chỗ hở: thiếu bao nhiêu, nằm giữa hai mốc nào, và nút ghi bù.
class _GapTile extends StatelessWidget {
  const _GapTile({
    required this.gap,
    required this.busy,
    required this.onFill,
  });

  final LedgerGap gap;
  final bool busy;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isIncome = gap.direction == TxnDirection.income;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: isIncome ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatSigned(gap.amount, isIncome: isIncome),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Xảy ra trong khoảng ${formatDay(gap.from)} ${formatTime(gap.from)}'
              ' → ${formatDay(gap.to)} ${formatTime(gap.to)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Ngân hàng báo số dư ${formatMoney(gap.actual)}, '
              'sổ tính ra ${formatMoney(gap.expected)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : onFill,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_rounded),
                label: const Text('Ghi khoản bù'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ngân hàng lệch quá nhiều mắt xích — nói nguyên nhân thay vì đổ ra một danh
/// sách dài mà chỗ nào cũng đỏ.
class _UnreliableNotice extends StatelessWidget {
  const _UnreliableNotice({required this.bank});

  final BankLedger bank;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      icon: Icons.alt_route_rounded,
      title: '${bank.bankName}: không đối soát được',
      message:
          '${bank.gaps.length}/${bank.links} mắt xích lệch. Gần như chắc chắn '
          'hai tài khoản khác nhau đang dùng chung tên nguồn này, nên số dư của '
          'chúng xen kẽ nhau chứ không nối tiếp. Tách tên nguồn ở màn "Nguồn '
          'ngân hàng" thì kiểm được.',
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    );
  }
}

/// Ngân hàng không bao giờ gửi số dư: không kết luận được gì, nhưng phải nói
/// ra — im lặng thì user tưởng đã kiểm hết.
class _BlindSpotNotice extends StatelessWidget {
  const _BlindSpotNotice({required this.banks});

  final List<String> banks;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      icon: Icons.visibility_off_outlined,
      title: 'Không kiểm được: ${banks.join(', ')}',
      message:
          'Thông báo của những nguồn này không kèm số dư nên không có gì để đối '
          'chiếu. Giao dịch bị lọt ở đây sẽ không bị phát hiện.',
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    );
  }
}

class _NothingToCheck extends StatelessWidget {
  const _NothingToCheck();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.fact_check_outlined,
      title: 'Chưa có gì để kiểm',
      message:
          'Kiểm sổ đối chiếu số dư ngân hàng gửi kèm thông báo với số dư sổ tự '
          'cộng ra. Cần ít nhất vài giao dịch ngân hàng có số dư mới bắt đầu '
          'được.',
    );
  }
}
