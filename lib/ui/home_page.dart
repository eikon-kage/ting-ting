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
import 'theme/app_theme.dart';
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

  /// Ô tìm kiếm chỉ hiện khi được gọi. Nó nằm trên thanh tiêu đề thay cho tên
  /// app: để nó thường trực giữa màn thì mất một dòng cho thứ hiếm khi dùng.
  bool _searching = false;

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

  Future<void> _openPage(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

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

  /// Mở ô tìm kiếm, hoặc đóng nó lại và bỏ luôn từ khoá — đóng mà vẫn còn lọc
  /// thì danh sách thiếu giao dịch mà không còn gì trên màn giải thích tại sao.
  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _query.clear();
      _controller.queryChanged('');
    }
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
          title: _searching
              ? TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Tìm nội dung, ghi chú...',
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: _controller.queryChanged,
                )
              : const Text('Ting Ting'),
          actions: [
            IconButton(
              tooltip: _searching ? 'Đóng tìm kiếm' : 'Tìm kiếm',
              icon: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
              ),
              onPressed: _toggleSearch,
            ),
            PopupMenuButton<String>(
              tooltip: 'Cài đặt',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) => switch (value) {
                'search' => _openPage(const SearchPage()),
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
                  value: 'search',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.tune_rounded),
                    title: Text('Lọc nâng cao'),
                  ),
                ),
                PopupMenuDivider(),
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
          child: CustomScrollView(
            // Kéo xuống để nạp lại phải chạy cả khi danh sách ngắn hơn màn hình.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_controller.platformSupported)
                      const _UnsupportedPlatformBanner(),
                    if (_controller.needsPermission)
                      _PermissionBanner(onGrant: _controller.requestPermission),
                    _OverviewCard(
                      wallets: _controller.wallets,
                      totals: _controller.totals,
                      rangeLabel: _rangeLabel(_controller),
                      onEdit: _editBalance,
                    ),
                    _FilterBar(
                      controller: _controller,
                      onPickStart: () => _pickDate(isStart: true),
                      onPickEnd: () => _pickDate(isStart: false),
                    ),
                  ],
                ),
              ),
              if (_controller.loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (!_controller.hasTxns)
                SliverToBoxAdapter(
                  child: _EmptyState(filtering: _controller.hasFilter),
                )
              else
                // Mỗi ngày là một nhóm riêng để tiêu đề ngày dính lại trên đỉnh
                // trong lúc cuộn: danh sách dài thì luôn biết đang xem ngày nào.
                for (final day in _controller.days)
                  SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _DayHeaderDelegate(
                          day: day.day,
                          total: day.net,
                        ),
                      ),
                      SliverList.builder(
                        itemCount: day.txns.length,
                        itemBuilder: (_, index) {
                          final txn = day.txns[index];
                          return _TxnTile(
                            txn: txn,
                            onTap: () => _openTxnSheet(txn),
                          );
                        },
                      ),
                    ],
                  ),
              // Chừa chỗ cho nút "Thêm" khỏi che dòng cuối.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
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

/// Nhãn ngắn cho khoảng đang lọc: tên chip dựng sẵn nếu khớp, không thì hai đầu
/// ngày rút gọn.
String _rangeLabel(HomeController controller) {
  final preset = controller.activePreset;
  if (preset != null) return preset.label;
  final from = controller.from;
  final to = controller.to;
  if (from == null && to == null) return DateFilterPreset.all.label;
  if (from == null) return 'Đến ${formatDayShort(to!)}';
  if (to == null) return 'Từ ${formatDayShort(from)}';
  return '${formatDayShort(from)} – ${formatDayShort(to)}';
}

/// Một hàng chip khoảng ngày. Lịch chọn tay nằm sau chip cuối cùng chứ không
/// bày sẵn: chín phần mười lượt xem rơi vào một trong bốn khoảng dựng sẵn, để
/// hai nút lịch thường trực là mất một dòng cho phần thiểu số.
class _FilterBar extends StatefulWidget {
  const _FilterBar({
    required this.controller,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final HomeController controller;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  bool _showCalendar = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final active = controller.activePreset;
    // Khoảng do user tự chọn thì không chip nào sáng lên được — mở sẵn lịch ra
    // để nhãn "01/07 – 15/07" có chỗ bấm mà sửa.
    final custom = active == null && controller.hasDateFilter;
    final open = _showCalendar || custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final preset in DateFilterPreset.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(preset.label),
                    selected: active == preset,
                    onSelected: (_) {
                      setState(() => _showCalendar = false);
                      controller.applyPreset(preset);
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  avatar: const Icon(Icons.event_rounded, size: 18),
                  label: Text(custom ? _rangeLabel(controller) : 'Chọn ngày'),
                  selected: custom,
                  onSelected: (_) =>
                      setState(() => _showCalendar = !_showCalendar),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? DateRangeBar(
                  from: controller.from,
                  to: controller.to,
                  onPickStart: widget.onPickStart,
                  onPickEnd: widget.onPickEnd,
                  onClear: controller.hasDateFilter
                      ? () {
                          setState(() => _showCalendar = false);
                          controller.clearDateRange();
                        }
                      : null,
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                )
              : const SizedBox(width: double.infinity),
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

/// Thẻ tóm tắt duy nhất của màn hình: tiền đang có ở trên, thu chi của khoảng
/// đang lọc ở dưới.
///
/// Trước đây là hai thẻ rời chiếm gần nửa màn hình trước khi thấy giao dịch đầu
/// tiên. Gộp lại còn một thẻ, và phần chia theo từng ngân hàng — thứ chỉ cần
/// khi muốn sửa số dư — giấu sau một nút bung.
class _OverviewCard extends StatefulWidget {
  const _OverviewCard({
    required this.wallets,
    required this.totals,
    required this.rangeLabel,
    required this.onEdit,
  });

  final WalletBalances wallets;
  final TxnTotals totals;
  final String rangeLabel;
  final EditBalanceRequest onEdit;

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = ChartPalette.of(context);
    final wallets = widget.wallets;
    final total = wallets.bankTotal + wallets.cash;
    final net = widget.totals.net;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 16,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tổng tiền',
                              style: theme.textTheme.labelMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatMoney(total),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: total < 0
                                  ? palette.expenseText
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tài khoản '
                          '${wallets.hasBankData ? formatMoney(wallets.bankTotal) : '—'}'
                          '  ·  Tiền mặt ${formatMoney(wallets.cash)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _WalletDetails(wallets: wallets, onEdit: widget.onEdit)
                : const SizedBox(width: double.infinity),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: scheme.outlineVariant,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.rangeLabel, style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FlowCell(
                        icon: Icons.south_west_rounded,
                        label: 'Thu',
                        value: formatMoney(widget.totals.income),
                        color: palette.incomeText,
                      ),
                    ),
                    Expanded(
                      child: _FlowCell(
                        icon: Icons.north_east_rounded,
                        label: 'Chi',
                        value: formatMoney(widget.totals.expense),
                        color: palette.expenseText,
                      ),
                    ),
                    Expanded(
                      child: _FlowCell(
                        label: 'Còn lại',
                        value: formatSigned(net.abs(), isIncome: net >= 0),
                        color: net >= 0
                            ? palette.incomeText
                            : palette.expenseText,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Phần bung ra của thẻ tóm tắt: mỗi ví một dòng, bấm vào để sửa số dư.
class _WalletDetails extends StatelessWidget {
  const _WalletDetails({required this.wallets, required this.onEdit});

  final WalletBalances wallets;
  final EditBalanceRequest onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final banks = wallets.banks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, indent: 16, endIndent: 16),
        const SizedBox(height: 4),
        // Chưa bắt được ngân hàng nào thì vẫn phải có một dòng bấm vào được,
        // không thì không có đường nào khai số dư ban đầu.
        if (banks.isEmpty)
          _WalletRow(
            icon: Icons.account_balance_outlined,
            name: 'Tài khoản',
            value: '—',
            onTap: () => onEdit(accountKind: AccountKind.bank, current: 0),
          )
        else
          for (final bank in banks)
            _WalletRow(
              icon: Icons.account_balance_outlined,
              name: bank.bankName,
              hint: 'ghi nhận ${formatDayShort(bank.at)}',
              value: formatMoney(bank.balance),
              onTap: () => onEdit(
                accountKind: AccountKind.bank,
                current: bank.balance,
                walletName: bank.bankName,
              ),
            ),
        _WalletRow(
          icon: Icons.payments_outlined,
          name: AccountKind.cash.label,
          value: formatMoney(wallets.cash),
          valueColor: wallets.cash < 0 ? palette.expenseText : null,
          onTap: () => onEdit(
            accountKind: AccountKind.cash,
            current: wallets.cash,
            walletName: AccountKind.cash.label,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Một dòng ví: icon, tên (kèm ngày ghi nhận nếu có), số dư và cây bút nhỏ báo
/// hiệu bấm được.
class _WalletRow extends StatelessWidget {
  const _WalletRow({
    required this.icon,
    required this.name,
    required this.value,
    required this.onTap,
    this.hint,
    this.valueColor,
  });

  final IconData icon;
  final String name;
  final String value;
  final String? hint;
  final Color? valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hint != null)
                    Text(hint!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: valueColor ?? scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit_rounded, size: 14, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// Một con số trong dải "Thu / Chi / Còn lại": nhãn nhỏ kèm mũi tên hướng tiền,
/// số tiền tô màu ngay bên dưới.
///
/// Bỏ huy hiệu tròn 38px của bản cũ — ba khối màu cạnh nhau trên cùng một dải
/// hút mắt mạnh hơn cả số tiền mà chúng đứng cạnh.
class _FlowCell extends StatelessWidget {
  const _FlowCell({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        // Nhãn cũng phải co được như con số: ba ô chia đều một thẻ hẹp, và
        // "Còn lại" đã sát mép khi user phóng to cỡ chữ hệ thống.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 3),
              ],
              Text(label, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tiêu đề ngày dính trên đỉnh danh sách khi cuộn.
///
/// Nền phải đục và đúng bằng màu nền màn hình: lúc dính lại, giao dịch chạy
/// ngay bên dưới nó.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DayHeaderDelegate({required this.day, required this.total});

  final DateTime day;
  final int total;

  static const double _height = 34;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: _height,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      alignment: Alignment.center,
      // "Thứ Ba, 28/07/2026" cạnh một tổng ngày hàng trăm triệu là vừa đủ tràn
      // một màn hẹp — nhãn ngày cắt bớt, con số thu nhỏ lại.
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatDayHeader(day),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatSigned(total.abs(), isIncome: total >= 0),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate old) => true;
}

/// Một dòng giao dịch. Dùng chung giữa màn chính và màn tìm kiếm.
///
/// Tự dựng bằng [Row] thay vì [ListTile]: dòng này lặp lại hàng trăm lần trong
/// một lần cuộn, nên khoảng đệm rộng rãi của [ListTile] (76px một dòng) làm màn
/// hình chỉ chứa nổi bảy tám giao dịch. Bản này cao khoảng 56px.
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
    // Giờ đứng trước: trong một nhóm ngày thì ngân hàng nào hay lặp lại, còn
    // giờ mới là thứ dùng để định vị giao dịch.
    final meta = [
      formatTime(txn.postTime),
      txn.bankName,
      if (txn.isDebt)
        '${txn.debtType!.label}${txn.person != null ? ' · ${txn.person}' : ''}',
      if (txn.isTransfer) 'chuyển ví',
      if (txn.excluded) 'không tính',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        child: Row(
          children: [
            // Icon tô nền nhạt cùng màu với số tiền: liếc qua là biết tiền vào
            // hay ra mà không cần đọc dấu +/−.
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.12),
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
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    txn.description?.isNotEmpty == true
                        ? txn.description!
                        : txn.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (txn.needsReview || txn.needsPerson) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: theme.colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Số tiền dài (hàng trăm triệu) không được đẩy tên giao dịch co lại
            // tới mức không đọc nổi — chặn bề ngang rồi thu nhỏ chữ nếu cần.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatSigned(txn.amount, isIncome: isIncome),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                    decoration: muted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ],
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
              showSelectedIcon: false,
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
    // Warning, not error. Nothing has failed here — the permission is simply
    // still to be granted, and `errorContainer`'s deep red claimed otherwise.
    final (background, foreground) = AppTheme.warningTone(scheme);
    return NoticeBanner(
      icon: Icons.notifications_off_rounded,
      title: 'Chưa có quyền đọc thông báo',
      message:
          'Bật "Ting Ting" trong Cài đặt > Quyền truy cập thông báo để app tự '
          'ghi giao dịch.',
      background: background,
      foreground: foreground,
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
