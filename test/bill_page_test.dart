import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ting_ting/data/data_store.dart';
import 'package:ting_ting/models/models.dart';
import 'package:ting_ting/ui/bill_page.dart';
import 'package:ting_ting/ui/bills_page.dart';
import 'package:ting_ting/ui/theme/app_theme.dart';

/// Màn chia bill xếp tên người bằng [Wrap] và số tiền bằng [Row], nên tên dài
/// với nhóm đông là chỗ dễ tràn ngang nhất. Test dựng màn thật trên màn hình
/// hẹp với dữ liệu xấu.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final data = DataStore.instance;

  /// Đẩy khung hình cho tới khi controller nạp xong — truy vấn sqlite chạy
  /// ngoài đồng hồ giả của `testWidgets` nên `pump` suông sẽ treo mãi.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<Bill> seed() async {
    final bill = Bill.create(
      title: 'Chuyến đi Đà Lạt của phòng kinh doanh',
      others: const ['Nguyễn Văn Minh', 'Lan', 'Huy', 'Chị Hương'],
    );
    await data.bills.save(bill);
    await data.bills.saveItem(
      BillItem.create(
        billKey: bill.key,
        label: 'Ăn tối nhà hàng ngoài trời',
        amount: 4350000,
        payer: Bill.me,
        mode: BillSplitMode.equal,
        shares: const [],
        at: DateTime(2026, 7, 30, 19),
      ),
    );
    await data.bills.saveItem(
      BillItem.create(
        billKey: bill.key,
        label: 'Vé vào cổng',
        amount: 500000,
        payer: 'Nguyễn Văn Minh',
        mode: BillSplitMode.custom,
        shares: const [BillShare(Bill.me, 100000), BillShare('Lan', 250000)],
        at: DateTime(2026, 7, 30, 20),
      ),
    );
    return bill;
  }

  tearDown(() async {
    for (final entry in await data.bills.overview()) {
      await data.bills.remove(entry.bill.key);
    }
  });

  testWidgets('màn chia bill không tràn trên màn hẹp', (tester) async {
    late final Bill bill;
    await tester.runAsync(() async => bill = await seed());
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BillPage(billKey: bill.key),
      ),
    );
    await settle(tester);

    // Mình trả hộ 4.350.000, phần mình chỉ là 870.000 + 100.000.
    expect(find.textContaining('Bạn đang được nhận lại'), findsOneWidget);

    // Cuộn hết màn: chỗ tràn nào cũng lộ ra trong lúc cuộn qua.
    await tester.scrollUntilVisible(find.text('Chốt sổ'), 200);
    expect(find.textContaining('đưa Tôi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet thêm khoản mở ra đủ các lựa chọn', (tester) async {
    late final Bill bill;
    await tester.runAsync(() async => bill = await seed());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BillPage(billKey: bill.key),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Thêm khoản'));
    await settle(tester);

    expect(find.text('Ai trả'), findsOneWidget);
    expect(find.text('Chia đều'), findsOneWidget);
    expect(find.text('Mỗi người một khoản'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tạo bill mới rồi mở thẳng vào nó', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const BillsPage()),
    );
    await settle(tester);

    await tester.tap(find.text('Bill mới'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Lẩu tối qua');
    await tester.enterText(find.byType(TextField).last, 'Nam');
    await tester.pump();
    await tester.tap(find.text('Tạo'));
    await settle(tester);

    // Tên còn nằm trong ô nhập vẫn được tính là một người, không cần Enter.
    expect(find.text('Lẩu tối qua'), findsWidgets);
    expect(find.text('Nam'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
