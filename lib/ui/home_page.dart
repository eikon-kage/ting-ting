import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/txn_alerts.dart';
import 'add_txn_page.dart';
import 'backup_page.dart';
import 'categories_page.dart';
import 'controllers/home_controller.dart';
import 'controllers/txn_detail_controller.dart';
import 'debt_page.dart';
import 'digest_page.dart';
import 'edit_balance_sheet.dart';
import 'format.dart';
import 'ledger_audit_page.dart';
import 'raw_log_page.dart';
import 'rules_page.dart';
import 'search_page.dart';
import 'sources_page.dart';
import 'theme/chart_palette.dart';
import 'widgets/category_chips.dart';
import 'widgets/date_range_bar.dart';
import 'widgets/empty_state.dart';

/// Màn chính: số dư hai ví, tổng thu chi tháng và danh sách giao dịch.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.reloadSignal});

  /// Bắn ra từ [RootShell] khi tab này được chọn lại, để nạp lại số liệu.
  final ValueListenable<int>? reloadSignal;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _controller = HomeController();
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.init();
    widget.reloadSignal?.addListener(_controller.refresh);
    TxnAlerts.instance.pendingEditTxnId.addListener(_handlePendingEdit);
    TxnAlerts.instance.pendingDigest.addListener(_handlePendingDigest);
    _handlePendingEdit();
    _handlePendingDigest();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.reloadSignal?.removeListener(_controller.refresh);
    TxnAlerts.instance.pendingEditTxnId.removeListener(_handlePendingEdit);
    TxnAlerts.instance.pendingDigest.removeListener(_handlePendingDigest);
    _query.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quay lại app sau khi bật quyền trong Settings -> cập nhật lại banner.
    if (state == AppLifecycleState.resumed) {
      _controller.refreshPermission();
      _controller.refresh();
    }
  }

  /// User vừa bấm "Sửa" trên thông báo (hoặc bấm vào thân thông báo) -> mở
  /// thẳng sheet chi tiết của giao dịch đó.
  Future<void> _handlePendingEdit() async {
    final txnId = TxnAlerts.instance.pendingEditTxnId.value;
    if (txnId == null) return;
    TxnAlerts.instance.pendingEditTxnId.value = null;
    await TxnAlerts.instance.cancel(txnId);
    final txn = await _controller.txnById(txnId);
    if (txn == null || !mounted) return;
    await _openTxnSheet(txn);
  }

  /// User vừa bấm vào lời nhắc sáng thứ Hai -> mở thẳng màn "Nhìn lại".
  void _handlePendingDigest() {
    if (!TxnAlerts.instance.pendingDigest.value) return;
    TxnAlerts.instance.pendingDigest.value = false;
    if (!mounted) return;
    _openPage(const DigestPage());
  }

  Future<void> _openPage(Widget page) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page),
  );

  /// Mở lịch cho một đầu của khoảng ngày, đầu kia giữ nguyên — chọn mỗi "Từ
  /// ngày" là ra "từ hôm đó đến nay".
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await pickRangeDate(
      context,
      isStart: isStart,
      initial: (isStart ? _controller.from : _controller.to) ?? DateTime.now(),
    );
    if (picked == null) return;
    _controller.setDateRange(
      from: isStart ? picked : _controller.from,
      to: isStart ? _controller.to : picked,
    );
  }

  void _clearQuery() {
    _query.clear();
    _controller.queryChanged('');
  }

  /// Số dư trên thẻ lệch với thực tế -> mở sheet nhập số đúng. Không cần tự
  /// gọi refresh: sheet ghi giao dịch xong thì chuông `data.changes` reo.
  void _editBalance({
    required AccountKind accountKind,
    required int current,
    String? walletName,
  }) {
    showEditBalanceSheet(
      context,
      accountKind: accountKind,
      current: current,
      walletName: walletName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Ting Ting'),
        actions: [
          IconButton(
            tooltip: 'Lọc nâng cao',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _openPage(const SearchPage()),
          ),
          PopupMenuButton<String>(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => switch (value) {
              'digest' => _openPage(const DigestPage()),
              'audit' => _openPage(const LedgerAuditPage()),
              'backup' => _openPage(const BackupPage()),
              'sources' => _openPage(const SourcesPage()),
              'categories' => _openPage(const CategoriesPage()),
              'rules' => _openPage(const RulesPage()),
              _ => _openPage(const RawLogPage()),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'digest',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.insights_rounded),
                  title: Text('Nhìn lại'),
                ),
              ),
              PopupMenuItem(
                value: 'audit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.fact_check_outlined),
                  title: Text('Kiểm sổ'),
                ),
              ),
              PopupMenuItem(
                value: 'sources',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.account_balance_outlined),
                  title: Text('Nguồn ngân hàng'),
                ),
              ),
              PopupMenuItem(
                value: 'categories',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.category_outlined),
                  title: Text('Nhóm chi tiêu'),
                ),
              ),
              PopupMenuItem(
                value: 'rules',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.rule_rounded),
                  title: Text('Quy tắc phân loại'),
                ),
              ),
              PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.backup_outlined),
                  title: Text('Sao lưu'),
                ),
              ),
              PopupMenuItem(
                value: 'log',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.notifications_none_rounded),
                  title: Text('Nhật ký thông báo'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Thêm giao dịch',
        onPressed: () => _openPage(const AddTxnPage()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm'),
      ),
      body: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (!_controller.platformSupported)
              const _UnsupportedPlatformBanner(),
            if (_controller.needsPermission)
              _PermissionBanner(onGrant: _controller.requestPermission),
            _BalanceCard(
              wallets: _controller.wallets,
              onEdit: _editBalance,
            ),
            _FilterBar(
              controller: _controller,
              queryController: _query,
              onClearQuery: _clearQuery,
              onPickStart: () => _pickDate(isStart: true),
              onPickEnd: () => _pickDate(isStart: false),
            ),
            _SummaryCard(totals: _controller.totals),
            if (_controller.loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_controller.hasTxns)
              _EmptyState(filtering: _controller.hasFilter)
            else
              for (final day in _controller.days) ...[
                _DayHeader(day: day.day, total: day.net),
                for (final txn in day.txns)
                  _TxnTile(txn: txn, onTap: () => _openTxnSheet(txn)),
              ],
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _openTxnSheet(Txn txn) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TxnDetailSheet(txn: txn),
  );
}

/// Ô tìm kiếm + khoảng ngày + mấy chip khoảng dựng sẵn.
///
/// Thay cho nút lùi/tiến tháng cũ: xem tháng nào vẫn chỉ một cú bấm ("Tháng
/// này" / "Tháng trước"), nhưng giờ chọn được khoảng bất kỳ và lọc theo chữ.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.queryController,
    required this.onClearQuery,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final HomeController controller;
  final TextEditingController queryController;
  final VoidCallback onClearQuery;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final active = controller.activePreset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            controller: queryController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Tìm nội dung, ghi chú...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: controller.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xoá từ khoá',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: onClearQuery,
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: controller.queryChanged,
          ),
        ),
        DateRangeBar(
          from: controller.from,
          to: controller.to,
          onPickStart: onPickStart,
          onPickEnd: onPickEnd,
          onClear: controller.hasDateFilter ? controller.clearDateRange : null,
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final preset in DateFilterPreset.values)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: ChoiceChip(
                    label: Text(preset.label),
                    selected: active == preset,
                    onSelected: (_) => controller.applyPreset(preset),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Yêu cầu mở sheet sửa số dư. [walletName] để `null` khi ví chưa tồn tại.
typedef EditBalanceRequest =
    void Function({
      required AccountKind accountKind,
      required int current,
      String? walletName,
    });

/// Số dư hiện có, tách theo hai ví. Thẻ nổi bật nhất màn hình nên tô nền cam
/// nhạt — nhìn phát thấy ngay tổng tiền đang có.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallets, required this.onEdit});

  final WalletBalances wallets;
  final EditBalanceRequest onEdit;

  /// Tổng của nhiều ngân hàng thì không sửa thẳng được — phải chọn đúng ví ở
  /// danh sách bên dưới. Chưa có ngân hàng nào thì bấm vào để khai ví đầu tiên.
  VoidCallback? _editBankTotal(List<BankBalance> banks) => switch (banks) {
    [] => () => onEdit(accountKind: AccountKind.bank, current: 0),
    [final only] => () => onEdit(
      accountKind: AccountKind.bank,
      current: only.balance,
      walletName: only.bankName,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = ChartPalette.of(context);
    final banks = wallets.banks;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _WalletCell(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Tài khoản',
                    value: wallets.hasBankData
                        ? formatMoney(wallets.bankTotal)
                        : '—',
                    color: scheme.onPrimaryContainer,
                    onTap: _editBankTotal(banks),
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.18),
                ),
                Expanded(
                  child: _WalletCell(
                    icon: Icons.payments_rounded,
                    label: 'Tiền mặt',
                    value: formatMoney(wallets.cash),
                    color: wallets.cash < 0
                        ? palette.expenseText
                        : scheme.onPrimaryContainer,
                    onTap: () => onEdit(
                      accountKind: AccountKind.cash,
                      current: wallets.cash,
                      walletName: AccountKind.cash.label,
                    ),
                  ),
                ),
              ],
            ),
            if (banks.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 10),
              for (final bank in banks)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onEdit(
                    accountKind: AccountKind.bank,
                    current: bank.balance,
                    walletName: bank.bankName,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 16,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bank.bankName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          '${formatMoney(bank.balance)} · ${formatDay(bank.at)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// Một ví trong thẻ số dư: icon + nhãn nhỏ + số tiền cỡ lớn.
///
/// [onTap] khác `null` thì cả ô bấm được để sửa số dư, và có thêm cây bút nhỏ
/// cạnh nhãn — không có nó thì không ai đoán ra là bấm được.
class _WalletCell extends StatelessWidget {
  const _WalletCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color: color.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals});

  final TxnTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final net = totals.net;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCell(
                    icon: Icons.south_west_rounded,
                    label: 'Thu',
                    value: formatMoney(totals.income),
                    color: palette.incomeText,
                  ),
                ),
                Expanded(
                  child: _SummaryCell(
                    icon: Icons.north_east_rounded,
                    label: 'Chi',
                    value: formatMoney(totals.expense),
                    color: palette.expenseText,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Còn lại',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatSigned(net.abs(), isIncome: net >= 0),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: net >= 0 ? palette.incomeText : palette.expenseText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô "Thu" / "Chi": icon tròn có nền nhạt cùng màu với con số, để phân biệt
/// hai ô mà không phải đọc nhãn.
class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.total});

  final DateTime day;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatDayHeader(day),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            formatSigned(total.abs(), isIncome: total >= 0),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng giao dịch. Dùng chung giữa màn chính và màn tìm kiếm.
class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn, required this.onTap});

  final Txn txn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final isIncome = txn.direction == TxnDirection.income;
    final muted = !txn.countsInReport;
    final amountColor = muted
        ? theme.colorScheme.outline
        : (isIncome ? palette.incomeText : palette.expenseText);
    return ListTile(
      onTap: onTap,
      // Icon tô nền nhạt cùng màu với số tiền: liếc qua là biết tiền vào hay ra
      // mà không cần đọc dấu +/−.
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: amountColor.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          txn.isDebt
              ? Icons.volunteer_activism_rounded
              : txn.isTransfer
              ? Icons.swap_horiz_rounded
              : (isIncome
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded),
          color: amountColor,
          size: 22,
        ),
      ),
      title: Text(
        txn.description?.isNotEmpty == true ? txn.description! : txn.category,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              [
                txn.bankName,
                formatTime(txn.postTime),
                if (txn.isDebt) '${txn.debtType!.label}${txn.person != null ? ' · ${txn.person}' : ''}',
                if (txn.isTransfer) 'chuyển ví',
                if (txn.excluded) 'không tính',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (txn.needsReview || txn.needsPerson) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.error_outline_rounded,
              size: 15,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ],
      ),
      trailing: Text(
        formatSigned(txn.amount, isIncome: isIncome),
        style: theme.textTheme.titleSmall?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.w700,
          decoration: muted ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

/// Dòng giao dịch dùng lại được từ màn khác.
class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, required this.onTap});

  final Txn txn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _TxnTile(txn: txn, onTap: onTap);
}

/// Bottom sheet chi tiết: sửa loại thu/chi, nhóm, ghi chú, nợ, chuyển ví, xoá.
class TxnDetailSheet extends StatefulWidget {
  const TxnDetailSheet({super.key, required this.txn});

  final Txn txn;

  @override
  State<TxnDetailSheet> createState() => _TxnDetailSheetState();
}

class _TxnDetailSheetState extends State<TxnDetailSheet> {
  late final _controller = TxnDetailController(txn: widget.txn);
  late final TextEditingController _noteController = TextEditingController(
    text: widget.txn.note ?? '',
  );

  @override
  void dispose() {
    _noteController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final txn = _controller.txn;
    final save = _controller.apply;
    final isIncome = txn.direction == TxnDirection.income;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatSigned(txn.amount, isIncome: isIncome),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isIncome ? palette.incomeText : palette.expenseText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${txn.bankName} · ${txn.accountKind.label} · '
              '${formatDay(txn.postTime)} ${formatTime(txn.postTime)}',
              style: theme.textTheme.bodySmall,
            ),
            if (txn.balance != null) ...[
              const SizedBox(height: 4),
              Text(
                'Số dư sau GD: ${formatMoney(txn.balance!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (txn.needsReview)
              _Notice(
                text: 'Không chắc đây là tiền vào hay ra — kiểm tra lại giúp.',
              ),
            if (txn.isDebt)
              _Notice(
                text: txn.needsPerson
                    ? 'Đã ghi vào sổ nợ nhưng chưa có tên người.'
                    : '${txn.debtType!.label} với ${txn.person}. '
                          'Khoản này không tính vào thu chi.',
              ),
            SegmentedButton<TxnDirection>(
              segments: const [
                ButtonSegment(
                  value: TxnDirection.expense,
                  label: Text('Chi'),
                  icon: Icon(Icons.north_east_rounded),
                ),
                ButtonSegment(
                  value: TxnDirection.income,
                  label: Text('Thu'),
                  icon: Icon(Icons.south_west_rounded),
                ),
              ],
              selected: {txn.direction},
              onSelectionChanged: (selection) => save(
                txn.copyWith(direction: selection.first, needsReview: false),
              ),
            ),
            const SizedBox(height: 16),
            Text('Nhóm', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            CategoryChips(
              selected: txn.category,
              onSelected: (category) => save(txn.copyWith(category: category)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _controller.editNote,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: txn.isTransfer,
              onChanged: (value) => save(txn.copyWith(isTransfer: value)),
              title: const Text('Chuyển giữa ví của mình'),
              subtitle: const Text('Rút ATM, nộp tiền — không tính thu chi'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: txn.excluded,
              onChanged: (value) => save(txn.copyWith(excluded: value)),
              title: const Text('Không tính vào báo cáo'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.volunteer_activism_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(txn.isDebt ? 'Sửa khoản nợ' : 'Ghi vào sổ nợ'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await showAssignDebtSheet(context, txn);
                await _controller.refresh();
              },
            ),
            // Thông báo gốc bày sẵn, không giấu sau nút bấm: mở chi tiết ra
            // phần lớn là để đối chiếu xem app đọc có đúng không.
            if (txn.rawContent.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Nội dung thông báo gốc', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  '${txn.rawTitle}\n${txn.rawContent}'.trim(),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Xoá giao dịch'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: () async {
                  await _controller.delete();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      icon: Icons.info_outline_rounded,
      title: text,
      margin: const EdgeInsets.only(bottom: 12),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NoticeBanner(
      icon: Icons.notifications_off_rounded,
      title: 'Chưa có quyền đọc thông báo',
      message:
          'Bật "Ting Ting" trong Cài đặt > Quyền truy cập thông báo để app tự '
          'ghi giao dịch.',
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
      action: FilledButton.icon(
        onPressed: onGrant,
        icon: const Icon(Icons.settings_rounded, size: 20),
        label: const Text('Mở cài đặt'),
      ),
    );
  }
}

class _UnsupportedPlatformBanner extends StatelessWidget {
  const _UnsupportedPlatformBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NoticeBanner(
      icon: Icons.phone_iphone_rounded,
      title: 'Trên iOS phải nhập tay',
      message:
          'iOS không cho phép app đọc thông báo của app khác, nên tính năng tự '
          'ghi chỉ chạy trên Android.',
      background: scheme.surfaceContainerHigh,
      foreground: scheme.onSurface,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtering});

  /// Đang lọc mà rỗng thì lỗi ở bộ lọc, không phải app chưa ghi được gì — hai
  /// tình huống này cần hai lời nhắc khác hẳn nhau.
  final bool filtering;

  @override
  Widget build(BuildContext context) {
    if (filtering) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Không tìm thấy giao dịch nào',
        message: 'Thử đổi từ khoá hoặc nới khoảng ngày ra.',
      );
    }
    return const EmptyState(
      icon: Icons.notifications_active_rounded,
      title: 'Chưa có giao dịch nào',
      message:
          'Sau khi app ngân hàng bắn thông báo, vào mục Nguồn để bật app đó lên.',
    );
  }
}
