import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/ui/theme/app_theme.dart';

/// While a chip animates between selected and unselected, its background must
/// stay within the two colours it is travelling between.
///
/// `RawChip._getBackgroundColor` builds a `ColorTween` from the unselected fill
/// to the selected one, but works out the "unselected" end by calling
/// `resolveColor` without passing `selectedColor`. While the chip is selected,
/// `_IndividualOverrides` returns `null` for that call and drops through to the
/// M3 default, `secondaryContainer` — `#FF9969` under this app's seed. That
/// becomes the tween's starting point, so tapping a chip flashes a frame of
/// saturated orange before settling.
///
/// Declaring the fill through `backgroundColor` + `selectedColor` cannot close
/// this; the hole is the call that never receives `selectedColor`. Only
/// `color` does, because `resolve` short-circuits on it.
///
/// The assertion is written against the theme's own `primaryContainer` rather
/// than a fixed threshold. Both endpoints are warm tints by design, so "is this
/// frame warm" cannot tell a bug from the intended colour — but the leaked
/// default is far more saturated than either endpoint, and that is what gets
/// measured.
void main() {
  /// How far red runs ahead of blue, in 0–255 units. A stand-in for saturation
  /// that is enough here because every colour involved sits on the same warm
  /// hue: the endpoints land near 15 and 54, the leaked default at 150.
  double warmth(Color c) => (c.r - c.b) * 255;

  final scheme = AppTheme.light().colorScheme;

  /// The selected fill is the warmest colour a frame is allowed to reach. The
  /// margin covers rounding in the tween, not a second colour.
  final ceiling = warmth(scheme.primaryContainer) + 8;

  Color? chipFill(WidgetTester tester) {
    final ink = tester.widget<Ink>(find.byType(Ink).first);
    return (ink.decoration as ShapeDecoration).color;
  }

  /// Taps, then inspects every frame until the animation stops. Returns the
  /// frames that overshot [ceiling].
  Future<List<String>> tapAndWatch(WidgetTester tester, Finder chip) async {
    final overshot = <String>[];
    await tester.tap(chip);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      final fill = chipFill(tester);
      if (fill != null && warmth(fill) > ceiling) {
        overshot.add('+${(i + 1) * 25}ms: $fill (warmth ${warmth(fill).round()})');
      }
    }
    await tester.pumpAndSettle();
    return overshot;
  }

  Widget host(Widget chip) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: chip)),
  );

  testWidgets('FilterChip stays within its endpoints, both directions', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          FilterChip(
            label: const Text('Tiền vào'),
            selected: selected,
            onSelected: (_) => setState(() => selected = !selected),
          ),
        ),
      ),
    );

    final chip = find.byType(FilterChip);
    expect(await tapAndWatch(tester, chip), isEmpty, reason: 'selecting');
    expect(await tapAndWatch(tester, chip), isEmpty, reason: 'deselecting');
  });

  testWidgets('ChoiceChip stays within its endpoints', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => host(
          ChoiceChip(
            label: const Text('Ăn uống'),
            selected: selected,
            onSelected: (_) => setState(() => selected = !selected),
          ),
        ),
      ),
    );

    expect(await tapAndWatch(tester, find.byType(ChoiceChip)), isEmpty);
  });
}
