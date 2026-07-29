import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/ui/theme/app_theme.dart';

/// Nền chip trong lúc chuyển trạng thái chọn không được ánh cam.
///
/// `RawChip._getBackgroundColor` dựng `ColorTween` từ nền thường sang nền chọn,
/// nhưng tính đầu "nền thường" bằng `resolveColor` mà không truyền
/// `selectedColor`. Chip đang ở trạng thái chọn thì `_IndividualOverrides`
/// trả `null` cho lời gọi đó và rơi xuống mặc định M3 `secondaryContainer` —
/// với hạt giống của app là `#FF9969`. Khai nền bằng `backgroundColor` +
/// `selectedColor` sẽ không bịt được, phải khai bằng `color`.
///
/// Test này canh đúng chỗ đó: đổi `chipTheme` về cặp kia là nó đỏ ngay.
void main() {
  /// Nền của app đều là xám ấm, đỏ hơn lam nhiều nhất khoảng 12/255. Cam bão
  /// hoà chênh trên 100, nên ngưỡng 40 tách được hai bên mà không cập kênh.
  bool anhCam(Color c) => (c.r - c.b) * 255 > 40;

  Color? nenChip(WidgetTester tester) {
    final ink = tester.widget<Ink>(find.byType(Ink).first);
    return (ink.decoration as ShapeDecoration).color;
  }

  /// Bấm rồi soi từng frame tới khi animation dừng. Trả về các frame ánh cam.
  Future<List<String>> bamVaSoi(WidgetTester tester, Finder chip) async {
    final dinh = <String>[];
    await tester.tap(chip);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      final mau = nenChip(tester);
      if (mau != null && anhCam(mau)) {
        dinh.add('+${(i + 1) * 25}ms: $mau');
      }
    }
    await tester.pumpAndSettle();
    return dinh;
  }

  testWidgets('FilterChip không nháy cam khi chọn rồi bỏ chọn', (tester) async {
    var chon = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Center(
              child: FilterChip(
                label: const Text('Tiền vào'),
                selected: chon,
                onSelected: (_) => setState(() => chon = !chon),
              ),
            ),
          ),
        ),
      ),
    );

    final chip = find.byType(FilterChip);
    expect(await bamVaSoi(tester, chip), isEmpty, reason: 'lúc chọn');
    expect(await bamVaSoi(tester, chip), isEmpty, reason: 'lúc bỏ chọn');
  });

  testWidgets('ChoiceChip không nháy cam khi chọn', (tester) async {
    var chon = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Center(
              child: ChoiceChip(
                label: const Text('Ăn uống'),
                selected: chon,
                onSelected: (_) => setState(() => chon = !chon),
              ),
            ),
          ),
        ),
      ),
    );

    expect(await bamVaSoi(tester, find.byType(ChoiceChip)), isEmpty);
  });
}
