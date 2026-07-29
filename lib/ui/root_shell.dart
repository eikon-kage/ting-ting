import 'package:flutter/material.dart';

import 'bank_templates_page.dart';
import 'debt_page.dart';
import 'home_page.dart';
import 'stats_page.dart';

/// Khung ngoài cùng: bốn tab Thu chi, Sổ nợ, Báo cáo và Ngân hàng.
///
/// Dùng [IndexedStack] để mỗi tab giữ nguyên trạng thái khi chuyển qua lại —
/// tháng đang xem ở tab Thu chi không bị nhảy về tháng này.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  /// Tăng lên mỗi lần đổi tab để tab vừa hiện lên nạp lại số liệu — sửa nợ ở
  /// tab này làm số dư ở tab kia lệch đi.
  final ValueNotifier<int> _reload = ValueNotifier(0);

  @override
  void dispose() {
    _reload.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _index = index);
    _reload.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(reloadSignal: _reload),
          DebtPage(reloadSignal: _reload),
          StatsPage(reloadSignal: _reload),
          BankTemplatesPage(reloadSignal: _reload),
        ],
      ),
      // Gạch mảnh phía trên thanh tab: nền thanh tab và nền nội dung gần bằng
      // nhau nên không có đường kẻ thì hai vùng dính vào nhau.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Thu chi',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism_rounded),
              label: 'Sổ nợ',
            ),
            NavigationDestination(
              icon: Icon(Icons.donut_small_outlined),
              selectedIcon: Icon(Icons.donut_small_rounded),
              label: 'Báo cáo',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance_rounded),
              label: 'Ngân hàng',
            ),
          ],
        ),
      ),
    );
  }
}
