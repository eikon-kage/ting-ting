import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
}
