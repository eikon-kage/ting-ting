import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ting_ting/data/data_store.dart';
import 'package:ting_ting/models/models.dart';
import 'package:ting_ting/ui/controllers/category_catalog.dart';
import 'package:ting_ting/ui/home_page.dart';
import 'package:ting_ting/ui/theme/app_theme.dart';

/// Màn thu chi tự dựng dòng giao dịch và dải Thu/Chi/Còn lại bằng [Row] thay vì
/// [ListTile], nên mọi thứ dài ra đều có thể tràn ngang. Test dựng màn thật với
/// dữ liệu xấu nhất (tên dài, số tiền hàng trăm triệu) trên màn hình hẹp.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Txn txn({
    required String description,
    required int amount,
    TxnDirection direction = TxnDirection.expense,
    String bank = 'Vietcombank',
    int daysAgo = 0,
    DebtType? debtType,
    String? person,
    bool isTransfer = false,
    bool needsReview = false,
    AccountKind accountKind = AccountKind.bank,
  }) {
    final now = DateTime.now();
    return Txn(
      packageName: Txn.manualPackage,
      bankName: bank,
      direction: direction,
      amount: amount,
      description: description,
      category: 'Khác',
      rawTitle: bank,
      rawContent: description,
      postTime: DateTime(now.year, now.month, now.day - daysAgo, 10, 30),
      debtType: debtType,
      person: person,
      isTransfer: isTransfer,
      needsReview: needsReview,
      accountKind: accountKind,
    );
  }

  /// Đẩy khung hình cho tới khi controller nạp xong.
  ///
  /// Truy vấn sqlite chạy ngoài đồng hồ giả của `testWidgets`, nên phải nhường
  /// cho nó chạy thật bằng [WidgetTester.runAsync] rồi mới vẽ lại; `pump` suông
  /// sẽ treo mãi vì dữ liệu không bao giờ về.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const HomePage()),
    );
    await settle(tester);
  }

  testWidgets('màn thu chi không tràn với dữ liệu dài trên màn hẹp', (
    tester,
  ) async {
    final data = DataStore.instance;
    await tester.runAsync(() async {
      await CategoryCatalog.instance.init();
      for (final t in [
        txn(
          description:
              'THANH TOAN QR VNPAY CHUYEN KHOAN LIEN NGAN HANG '
              'CTY TNHH THUONG MAI DICH VU XUAT NHAP KHAU',
          amount: 987654321,
        ),
        txn(
          description: 'Luong thang 7',
          amount: 24500000,
          direction: TxnDirection.income,
          bank: 'MB Bank',
        ),
        txn(
          description: 'Cho vay',
          amount: 2000000,
          debtType: DebtType.lend,
          person: 'Nguyễn Văn Minh',
        ),
        txn(description: 'Rut ATM', amount: 3000000, isTransfer: true),
        txn(description: 'Chua ro', amount: 78000, needsReview: true),
        txn(description: 'Hom qua', amount: 55000, daysAgo: 1),
        txn(
          description: 'Tien mat',
          amount: 4350000,
          direction: TxnDirection.income,
          bank: 'Tiền mặt',
          accountKind: AccountKind.cash,
          daysAgo: 2,
        ),
      ]) {
        await data.txns.add(t);
      }
    });

    // iPhone SE — màn hẹp nhất còn được dùng nhiều.
    await pumpHome(tester, const Size(320, 640));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Còn lại'), findsOneWidget);

    // Bung phần chia theo ví ra: dòng ví cũng tự dựng bằng Row.
    await tester.tap(find.text('Tổng tiền'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // Mở lịch chọn ngày sau chip cuối — trên màn hẹp phải kéo hàng chip sang
    // trái mới thấy nó.
    await tester.scrollUntilVisible(
      find.text('Chọn ngày'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Chọn ngày'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // Cuộn qua danh sách để tiêu đề ngày dính vào đỉnh.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
