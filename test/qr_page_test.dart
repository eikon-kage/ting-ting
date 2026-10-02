import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ting_ting/data/data_store.dart';
import 'package:ting_ting/ui/qr_page.dart';
import 'package:ting_ting/ui/theme/app_theme.dart';

/// The QR screen builds its code as the user types and hands the same widget
/// tree to the image exporter, so a card that overflows or a code that never
/// appears is a broken feature, not a cosmetic slip.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // The screen remembers codes in the settings table, and the test database
    // is a file that outlives the run. Start every test from an empty list, or
    // the last run's saved code fills the form in this one.
    await DataStore.instance.settings.writeQrHistory(const []);
  });

  /// Lets the settings read off sqlite finish before painting again — the query
  /// runs outside the fake clock, so a plain `pump` would wait forever.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const QrPage()),
    );
    await settle(tester);
  }

  Future<void> pickBank(WidgetTester tester, String query, String name) async {
    await tester.tap(find.text('Chọn ngân hàng'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, query);
    await tester.pump();
    await tester.tap(find.text(name));
    await settle(tester);
  }

  /// The account number is the first field on the form.
  Future<void> enterAccount(WidgetTester tester, String account) async {
    await tester.enterText(find.byType(TextField).first, account);
    await settle(tester);
  }

  /// The card and the download button live at the far end of the list, which
  /// only builds what is on screen.
  Future<void> scrollToBottom(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await settle(tester);
  }

  /// `FilledButton.icon` builds a private subclass, which `byType` refuses to
  /// match, so the only button on the screen is found by shape instead.
  FilledButton downloadButton(WidgetTester tester) =>
      tester.widget<FilledButton>(
        find.byWidgetPredicate((widget) => widget is FilledButton),
      );

  testWidgets('shows no code until a bank and an account are in', (
    tester,
  ) async {
    await pumpPage(tester);
    await scrollToBottom(tester);

    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.textContaining('Chọn ngân hàng và nhập số tài khoản'),
      findsOneWidget,
    );
    expect(downloadButton(tester).onPressed, isNull);
  });

  testWidgets('draws the code once the account is filled in', (tester) async {
    await pumpPage(tester);
    await pickBank(tester, 'vietcom', 'Vietcombank');
    await enterAccount(tester, '0123456789');
    await scrollToBottom(tester);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(downloadButton(tester).onPressed, isNotNull);
  });

  testWidgets('turns the typed note into what the sender will see', (
    tester,
  ) async {
    await pumpPage(tester);
    await pickBank(tester, 'vietcom', 'Vietcombank');
    await enterAccount(tester, '0123456789');
    // Fourth field: account, holder, amount, then the note.
    await tester.enterText(find.byType(TextField).at(3), 'Trả tiền cơm');
    await settle(tester);

    expect(
      find.textContaining('Người chuyển thấy: TRA TIEN COM'),
      findsOneWidget,
    );
  });

  testWidgets('the card holds together on the narrowest phone in use', (
    tester,
  ) async {
    // iPhone SE. The card is a fixed 320 wide, which is the whole screen here.
    await pumpPage(tester, size: const Size(320, 640));
    await pickBank(tester, 'techcom', 'Techcombank');
    await enterAccount(tester, '19001234567890');
    await tester.enterText(find.byType(TextField).at(1), 'Nguyen Van A');
    await tester.enterText(find.byType(TextField).at(2), '1500000');
    await settle(tester);
    await scrollToBottom(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('1.500.000 đ'), findsOneWidget);
  });

  // Runs last on purpose: it is the only test that writes to the settings
  // table, and every test above expects a screen with nothing filled in.
  testWidgets('remembers a code and offers it again next time', (tester) async {
    await pumpPage(tester);
    await pickBank(tester, 'techcom', 'Techcombank');
    await enterAccount(tester, '19001234567890');
    await tester.enterText(find.byType(TextField).at(2), '250000');
    await settle(tester);
    await scrollToBottom(tester);

    await tester.tap(find.text('Lưu mã này'));
    await settle(tester);
    expect(find.text('Đã lưu mã này'), findsOneWidget);

    // The saved list reaches it, amount and all.
    await tester.tap(find.byTooltip('Mã đã lưu'));
    await settle(tester);
    expect(find.text('19001234567890 · 250.000 đ'), findsOneWidget);

    // Opening the screen again starts from that code rather than blank. An
    // empty tree first, or the framework reuses the identical `const QrPage()`
    // it is already showing and nothing is reopened at all.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await pumpPage(tester);
    final account = tester.widget<TextField>(find.byType(TextField).first);
    expect(account.controller?.text, '19001234567890');
    await scrollToBottom(tester);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('250.000 đ'), findsWidgets);
  });
}
