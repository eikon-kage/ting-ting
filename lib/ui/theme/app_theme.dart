import 'package:flutter/material.dart';

/// The app's theme: large readable type, rounded icons, one accent per scheme.
///
/// Only the dark scheme ships — `main.dart` pins `themeMode`. The light one is
/// kept building and tested, but nobody sees it, so weigh any claim it makes
/// about "the app" accordingly.
///
/// Both schemes start from [brand] through the `fidelity` variant and then
/// override most of what matters, because `fidelity` tracks the seed far too
/// closely for a background:
///
/// - the `surface` family comes out tinted in both — see [_neutralSurfaces]
///   for the light cream ramp and [_darkSurfaces] for the dark one;
/// - `primaryContainer` comes out as the raw seed — see
///   [_tintedPrimaryContainer], which also swaps the dark scheme's accents to
///   trustybot's blue.
///
/// The rule that survived every revision: keep backgrounds quiet and let the
/// accent carry the colour. Draining both leaves the app looking dead; tinting
/// both makes every screen look stained.
class AppTheme {
  const AppTheme._();

  /// Seed for the generated scheme — `oklch(0.705 0.213 47.604)`, just outside
  /// sRGB; clamped into gamut it lands on `#FF6900`, really
  /// `oklch(0.700 0.202 44.4)`.
  ///
  /// This used to be the app's identity, picked warm specifically to stay clear
  /// of trustybot, whose every chromatic colour sits in the blue–indigo–violet
  /// band (hue 247°–291°). That constraint was dropped by request: the dark
  /// scheme's accents are now taken straight from trustybot's own palette — see
  /// [_tintedPrimaryContainer]. The two apps are meant to look related now.
  ///
  /// What the seed still does is narrower than it looks. Both schemes override
  /// their surfaces by hand, and the dark one overrides `primary` and
  /// `primaryContainer` too, so this really only drives the light scheme's
  /// `primary` plus the `secondary` / `tertiary` / `error` roles that nothing
  /// currently paints with. Changing it moves less than the name suggests.
  ///
  /// Do not switch to `tonalSpot`, the M3 default variant: with this seed it
  /// wrings out most of the chroma and yields `#8E4D2E` for `primary`, the
  /// exact brown the app used before it moved to orange.
  static const Color brand = Color(0xFFFF6900);

  static ThemeData light() => _build(
    _tintedPrimaryContainer(
      _neutralSurfaces(
        ColorScheme.fromSeed(
          seedColor: brand,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
      ),
    ),
  );

  /// Replaces the light scheme's `surface` family with a warm cream ramp.
  ///
  /// `fidelity` tints the neutrals heavily: `surfaceContainerHigh` comes out
  /// `#FEE3D8`, a visible peach, and that role backs the chips, text fields,
  /// navigation bar and every secondary block — so the whole screen read as if
  /// a sheet of orange had been laid over it.
  ///
  /// The measure that matters here is how far the red channel runs ahead of
  /// blue. `fidelity` puts it at 38/255, which is the peach. A first pass cut
  /// it to 3–5, which killed the tint but left large areas — cards, banners,
  /// the overview panel — reading as flat grey, and the app looked drained.
  /// This ramp sits at 6–17: clearly warm, nowhere near peach.
  ///
  /// Only backgrounds and the text on them; `primary` still comes from the
  /// seed.
  ///
  /// Contrast on the new ramp: `onSurface` 16.26:1, `onSurfaceVariant` 7.72:1,
  /// dropping to 6.33:1 on `surfaceContainerHighest` — all clear of AA.
  static ColorScheme _neutralSurfaces(ColorScheme scheme) => scheme.copyWith(
    surface: const Color(0xFFFFFCF9),
    surfaceBright: const Color(0xFFFFFCF9),
    surfaceDim: const Color(0xFFF0E9E2),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFDF8F3),
    surfaceContainer: const Color(0xFFF8F2EB),
    surfaceContainerHigh: const Color(0xFFF3ECE4),
    surfaceContainerHighest: const Color(0xFFEDE5DC),
    onSurface: const Color(0xFF241D17),
    onSurfaceVariant: const Color(0xFF58504A),
    outline: const Color(0xFF8A8079),
    outlineVariant: const Color(0xFFE4DBD1),
  );

  static ThemeData dark() => _build(
    _tintedPrimaryContainer(
      _darkSurfaces(
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
      ),
    ),
  );

  /// Replaces the dark scheme's `surface` family with trustybot's dark ramp.
  ///
  /// `fidelity` pulls the dark neutrals toward the seed just as it does the
  /// light ones, so `surface` lands on `#1D100A` and the raised containers on
  /// `#362720`. Those are browns. On a phone they read as a tinted screen
  /// rather than as an app with a dark background.
  ///
  /// The three anchors come from `darkColors` in trustybot-mobile's
  /// `src/shared/theme/themes.ts`: `background` `#0E1116` is the base,
  /// `surface` `#1A1F26` the mid container, `border` `#2A3038` the top of the
  /// ramp. The remaining steps interpolate between them, so the whole family
  /// holds one hue — a cool blue-grey where blue leads red by 8–14/255. That
  /// coolness is the opposite of the light scheme, where the ramp is warm:
  /// warmth that reads as "cream" on white reads as "stained" on dark.
  ///
  /// The base used to be true `#000000`, for OLED. Lifting it to `#0E1116`
  /// gives up that power saving and buys back the shadows: against pure black
  /// the elevation ramp only reads by fill, and a card sitting one step up was
  /// a rectangle appearing out of nothing. Cards, sheets and the navigation bar
  /// all sit on `surfaceContainerLow`, which now has somewhere to sit.
  ///
  /// Only the surface roles. The accents on this ramp are set in
  /// [_tintedPrimaryContainer], which takes trustybot's blue.
  ///
  /// Contrast on the base: `onSurface` 15.4:1, `onSurfaceVariant` 7.7:1, and
  /// 5.4:1 where the variant sits on `surfaceContainerHighest` — all clear of
  /// AA. The chart colours hold up: income 9.7:1, expense 8.1:1.
  static ColorScheme _darkSurfaces(ColorScheme scheme) => scheme.copyWith(
    surface: const Color(0xFF0E1116),
    surfaceDim: const Color(0xFF0A0D11),
    surfaceBright: const Color(0xFF2E353F),
    surfaceContainerLowest: const Color(0xFF0A0D11),
    surfaceContainerLow: const Color(0xFF141922),
    surfaceContainer: const Color(0xFF1A1F26),
    surfaceContainerHigh: const Color(0xFF222831),
    surfaceContainerHighest: const Color(0xFF2A3038),
    onSurface: const Color(0xFFE6E8EB),
    onSurfaceVariant: const Color(0xFFA0A6AD),
    outline: const Color(0xFF79818C),
    outlineVariant: const Color(0xFF2A3038),
  );

  /// Softens `primaryContainer` into a pale tint of the brand orange.
  ///
  /// `fidelity` hands back the seed itself, `#FF6900` at full chroma. That role
  /// is only ever used as a solid fill, and always on large areas that sit on
  /// screen the whole time: the navigation indicator, selected chips, the
  /// segmented button, the date filter buttons, the debt overview card and its
  /// per-person header, the empty state circle, category avatars. Saturated
  /// orange across that much surface is genuinely hard to look at.
  ///
  /// A pale tint keeps the hue — so selection still reads as *colour* rather
  /// than as a darker shade of the background — while dropping the glare. Text
  /// on top carries the saturation instead, where the area is small.
  ///
  /// This replaced a neutral warm grey that removed the glare but left the app
  /// looking washed out: with the background already near-neutral, draining the
  /// accents too meant nothing on screen had colour except the FAB. Keep the
  /// backgrounds neutral and the accents tinted, not both neutral.
  ///
  /// The two schemes split the work differently, because the same recipe does
  /// not survive both backgrounds.
  ///
  /// On white, a pale tint is the signal and the text is only there to be
  /// read. On black that inverts. A mid-dark fill does not read as "tinted",
  /// it reads as a stain, and the debt overview card is a large enough panel to
  /// make that obvious. So the dark fill only lifts one step off the surface
  /// ramp and the accent moves into the foreground, where it sits on a small
  /// area and stays sharp.
  ///
  /// That leaves the dark fill nearly level with an unselected chip, 1.14:1, so
  /// it is not carrying selection on its own. The blue label against the grey
  /// one is, backed by w700 and the `outline` border — the same three cues the
  /// light scheme leans on.
  ///
  /// Contrast against `onPrimaryContainer` is 7.51:1 light and 4.93:1 dark.
  ///
  /// ## Why the dark accents are blue
  ///
  /// They are trustybot's, by request — `primary-500 #5B9CD6`, its declared
  /// "Brand blue. Default action color". This reverses the reasoning kept on
  /// [brand]; that note has been rewritten rather than left to contradict this
  /// one.
  ///
  /// Picking the shade was forced. `primary` is both the fill behind the FAB
  /// and filled buttons *and* a text colour for app bar icons, the focused
  /// field border and the selected navigation label. Those two jobs pull in
  /// opposite directions on the dark surface, and the scale cannot satisfy
  /// both:
  ///
  /// - `#2B5ED4` (650) carries white text at 5.75:1, but as a label on `surface`
  ///   it is 3.29:1 — under AA.
  /// - `#5B9CD6` (500) reads 6.46:1 on `surface`, but white on it is 2.93:1 —
  ///   well under AA.
  ///
  /// So 500 for the role and a dark navy for its foreground: `#08172B` gives
  /// 6.14:1 on the fill. Same trade the orange version made, same resolution.
  /// A white button label is not available in this hue at any usable shade.
  /// Background and foreground for "needs your attention", as distinct from
  /// "something failed".
  ///
  /// M3 has no warning role — it goes straight from `tertiary` to `error` — so
  /// anything of this kind had to borrow `errorContainer`, which is a deep red.
  /// Red is a claim that something broke. A missing notification permission has
  /// not broken anything; it is a task the user has not done yet, and dressing
  /// it as a failure both alarms and misinforms.
  ///
  /// The foreground is amber from trustybot's `warn` scale — `warn-400` light
  /// on dark, `warn-800` dark on light.
  ///
  /// The dark background is *not* from that scale. `warn-900` was tried and
  /// rendered as a muddy brown panel: amber ramps go brown at the dark end,
  /// which is the same stain that `#5C3620` produced in
  /// [_tintedPrimaryContainer]. The fix is the rule that section already
  /// establishes — lift the fill one step off the surface ramp and let the
  /// foreground carry the hue. `#2E2614` is that lift with a warm cast, 1.26:1
  /// off `surface`, and `NoticeBanner` adds a border at 20% of the foreground.
  ///
  /// The amber then reads at 9.31:1, so the warning is loud where it should be
  /// — in the icon and the words — and quiet where a large fill would only be
  /// dirty.
  ///
  /// Leave `errorContainer` alone for real errors — a redacted bank template,
  /// a failed import. If both appear at once they should not look alike.
  static (Color background, Color foreground) warningTone(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? (const Color(0xFF2E2614), const Color(0xFFFAC515))
      : (const Color(0xFFFEF7C3), const Color(0xFF854A0E));

  static ColorScheme _tintedPrimaryContainer(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? scheme.copyWith(
          primary: const Color(0xFF5B9CD6),
          onPrimary: const Color(0xFF08172B),
          primaryContainer: const Color(0xFF202A3A),
          // Same blue as `primary`, on purpose. The navigation label takes
          // `primary` while a chip label takes this one, and two different
          // blues for the one meaning — "selected" — reads as a mistake.
          // 4.93:1 on the container, so the chip label clears AA.
          onPrimaryContainer: const Color(0xFF5B9CD6),
        )
      : scheme.copyWith(
          primaryContainer: const Color(0xFFFFDFC9),
          onPrimaryContainer: const Color(0xFF7A2E00),
        );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _textTheme(base.textTheme, scheme);
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,

      // Icon mặc định nhỉnh hơn 24 một chút và dùng màu chữ phụ — icon xám nhạt
      // của Material đọc rất mờ trên nền sáng.
      iconTheme: IconThemeData(size: 24, color: scheme.onSurfaceVariant),
      primaryIconTheme: IconThemeData(color: scheme.primary),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // Bigger than titleLarge's 22: the header is the only anchor on pages
        // that are otherwise a wall of rows and numbers. Set here rather than
        // on titleLarge itself, which dialogs also use.
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        actionsIconTheme: IconThemeData(size: 26, color: scheme.primary),
        iconTheme: IconThemeData(size: 26, color: scheme.onSurface),
      ),

      // Thẻ phẳng có viền mảnh: đổ bóng làm màu nền bị đục, viền cho ranh giới
      // rõ hơn.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        // Luôn hiện nhãn: ba tab tên tiếng Việt, chỉ nhìn icon rất dễ đoán nhầm.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        // The selected label takes `primary` rather than `onPrimaryContainer`:
        // it sits below the indicator pill, not inside it, so it needs to read
        // as the accent colour on the bar's own background. 6.12:1 there.
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 4,
        iconSize: 26,
        extendedTextStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 10,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 44),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
        // Phải khai bằng `color` chứ không phải cặp `backgroundColor` +
        // `selectedColor`, dù cặp kia đọc gọn hơn.
        //
        // `RawChip._getBackgroundColor` dựng một `ColorTween` từ nền thường
        // sang nền chọn, và nó tính đầu "nền thường" bằng cách gọi
        // `resolveColor` mà không truyền `selectedColor`. Trong lúc chip đang ở
        // trạng thái chọn, `_IndividualOverrides.resolve` gặp `selected` thì
        // trả thẳng `selectedColor` — ở đây là `null` — nên rơi xuống mặc định
        // M3 `_FilterChipDefaultsM3.color`, tức `secondaryContainer`. Với hạt
        // giống này màu đó là `#FF9969`, cam sáng. Kết quả: bấm chọn thì nền
        // nháy nguyên một nhịp cam rồi mới fade về xám.
        //
        // `resolve` short-circuit ngay khi `color != null`, nên khai một
        // `WidgetStateProperty` là bịt được cả hai đầu tween.
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return scheme.primaryContainer;
          }
          return scheme.surfaceContainerHigh;
        }),
        // No checkmark on a selected chip. It shoves the label sideways on
        // select, so a row of chips reflows every tap, and it costs the width
        // of a glyph on a screen where these rows already scroll horizontally.
        //
        // Selection still has three cues without it: the tinted fill, the
        // darker `outline` border, and the label at w700 against w600. Two of
        // those survive greyscale, so this does not lean on colour alone.
        showCheckmark: false,
        // Nền chọn chỉ đậm hơn nền thường một nấc, nên viền phải gánh thêm:
        // chip đang chọn lấy `outline` đậm, chip thường giữ `outlineVariant`.
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? scheme.outline
                : scheme.outlineVariant,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        collapsedIconColor: scheme.onSurfaceVariant,
      ),
    );
  }

  /// Chữ to hơn mặc định một nấc, tiêu đề đậm hơn, và số dùng chữ số đều bề
  /// ngang (tabular) để các cột tiền thẳng hàng khi đọc lướt.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    const tabular = [FontFeature.tabularFigures()];
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        fontFeatures: tabular,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        fontFeatures: tabular,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        fontFeatures: tabular,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        fontFeatures: tabular,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFeatures: tabular,
      ),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15.5, height: 1.35),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14.5, height: 1.35),
      // Dòng phụ trong danh sách: nâng cỡ và dùng màu chữ phụ chuẩn thay vì
      // xám nhạt mặc định — trước đây rất khó đọc ngoài nắng.
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.35,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
        fontFeatures: tabular,
      ),
    );
  }
}
