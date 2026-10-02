import 'package:flutter/material.dart';

import 'mission_style.dart';

/// The app's theme: large readable type, rounded icons, one accent per scheme.
///
/// Both schemes ship; the user picks one from the ⋮ menu, see
/// `ThemeController`. Dark is the default.
///
/// Both schemes start from [brand] through the `fidelity` variant and then
/// override most of what matters, because `fidelity` tracks the seed far too
/// closely for a background:
///
/// - the `surface` family comes out tinted in both — see [_lightSurfaces]
///   and [_darkSurfaces];
/// - `primaryContainer` comes out as the raw seed — see
///   [_tintedPrimaryContainer], which also sets both schemes' accents.
///
/// Both follow the ARES VII "mission control" dashboard. Dark is the console
/// itself: slate panels on a faint cyan grid, safety-orange corner brackets,
/// off-white numerals, cyan for data and amber for caution. Light is the same
/// console printed as a flight plan: grey paper, slate ink, the orange and
/// cyan darkened until they read as text. The pieces `ThemeData` has no slot
/// for live in `mission_style.dart`.
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
  /// Neither scheme uses it for its accents; those are the ARES palette, set
  /// by hand in [_tintedPrimaryContainer]. What the seed still drives is the
  /// handful of roles nothing overrides and nothing currently paints with.
  /// Changing it moves far less than the name suggests.
  ///
  /// Do not switch to `tonalSpot`, the M3 default variant: with this seed it
  /// wrings out most of the chroma and yields `#8E4D2E` for `primary`, the
  /// exact brown the app used before it moved to orange.
  static const Color brand = Color(0xFFFF6900);

  static ThemeData light() => _build(
    _tintedPrimaryContainer(
      _lightSurfaces(
        ColorScheme.fromSeed(
          seedColor: brand,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
      ),
    ),
  );

  /// Replaces the light scheme's `surface` family with a grey paper ramp.
  ///
  /// `fidelity` tints the neutrals heavily — `surfaceContainerHigh` comes out
  /// `#FEE3D8`, a visible peach, and that role backs chips, fields and the
  /// navigation bar.
  ///
  /// The base `#F2F1EE` is a barely warm grey, so the white panels
  /// (`#FBFAF8`) lift off it the way the dark panels lift off the slate.
  /// `outlineVariant` is the ink at 10% on the base, the reference's `--line`
  /// inverted.
  ///
  /// Contrast on the base: `onSurface` 15.8:1, `onSurfaceVariant` 5.9:1.
  static ColorScheme _lightSurfaces(ColorScheme scheme) => scheme.copyWith(
    surface: const Color(0xFFF2F1EE),
    surfaceBright: const Color(0xFFFBFAF8),
    surfaceDim: const Color(0xFFE6E5E1),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFBFAF8),
    surfaceContainer: const Color(0xFFF6F5F2),
    surfaceContainerHigh: const Color(0xFFECEBE7),
    surfaceContainerHighest: const Color(0xFFE5E4E0),
    onSurface: const Color(0xFF14181F),
    onSurfaceVariant: const Color(0xFF585D65),
    outline: const Color(0xFF8A8F96),
    outlineVariant: const Color(0xFFDCDBD9),
    inverseSurface: const Color(0xFF1B1F26),
    onInverseSurface: const Color(0xFFE8E6E3),
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

  /// Replaces the dark scheme's `surface` family with the ARES slate ramp.
  ///
  /// `fidelity` pulls the dark neutrals toward the seed, so `surface` lands on
  /// `#1D100A` — a brown that reads as a tinted screen, not a dark one.
  ///
  /// Anchors from the reference's CSS: `--bg #0E1116` is the base, `--panel
  /// #12161D` backs cards, sheets and the navigation bar. The steps above are
  /// the panel lifted by the white overlays the reference uses for tiles and
  /// hover. `outlineVariant` is its `--line`, off-white at 9% on the base;
  /// `outline` is `--dim2`.
  ///
  /// Text is the reference's off-white `--t #E8E6E3` and `--dim #8B8F96`:
  /// 15.6:1 and 5.9:1 on the base, 4.9:1 for the dim one on
  /// `surfaceContainerHighest` — all clear of AA.
  static ColorScheme _darkSurfaces(ColorScheme scheme) => scheme.copyWith(
    surface: const Color(0xFF0E1116),
    surfaceDim: const Color(0xFF0A0D11),
    surfaceBright: const Color(0xFF262B33),
    surfaceContainerLowest: const Color(0xFF0A0D11),
    surfaceContainerLow: const Color(0xFF12161D),
    surfaceContainer: const Color(0xFF161A21),
    surfaceContainerHigh: const Color(0xFF1B1F26),
    surfaceContainerHighest: const Color(0xFF22262D),
    onSurface: const Color(0xFFE8E6E3),
    onSurfaceVariant: const Color(0xFF8B8F96),
    outline: const Color(0xFF5B6068),
    outlineVariant: const Color(0xFF222428),
    inverseSurface: const Color(0xFFE8E6E3),
    onInverseSurface: const Color(0xFF0E1116),
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
  /// The dark fill is a low orange cast, not much brighter than an unselected
  /// chip, so it is not carrying selection on its own. The orange label against
  /// the grey one is, backed by w700 and the `outline` border — the same three
  /// cues the light scheme leans on.
  ///
  /// Contrast against `onPrimaryContainer` is 7.51:1 light and 5.4:1 dark.
  ///
  /// ## The dark accents
  ///
  /// Straight from the ARES palette. `primary` is safety orange `#FF6B1A`,
  /// 6.6:1 on `surface`, with near-black `#140800` on top of it at 6.9:1 — the
  /// reference's own button text. The selected fill is that orange at 16% on
  /// the base, as on the reference's pressed segment, and the label on it stays
  /// the full orange at 5.4:1.
  ///
  /// `secondary` is the data cyan `#4EE1FF`, `tertiary` the caution amber
  /// `#FFB000`, `error` the alarm red `#FF4A3D`.
  ///
  /// Background and foreground for "needs your attention", as distinct from
  /// "something failed".
  ///
  /// M3 has no warning role — it goes straight from `tertiary` to `error` — so
  /// anything of this kind had to borrow `errorContainer`, which is a deep red.
  /// Red is a claim that something broke. A missing notification permission has
  /// not broken anything; it is a task the user has not done yet, and dressing
  /// it as a failure both alarms and misinforms.
  ///
  /// On dark it is the reference's caution banner: amber `#FFB000` over the
  /// same amber at 10% on the base, which lands at `#262114`. Amber ramps go
  /// brown at the dark end, so the fill stays one step off the surface and the
  /// foreground carries the hue — 10.1:1. `NoticeBanner` adds a border at 20%
  /// of the foreground. On light it is the amber at 18% on the panel with a
  /// dark amber `#8A5A00` on top, 5.1:1.
  ///
  /// Leave `errorContainer` alone for real errors — a redacted bank template,
  /// a failed import. If both appear at once they should not look alike.
  static (Color background, Color foreground) warningTone(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? (const Color(0xFF262114), const Color(0xFFFFB000))
      : (const Color(0xFFFCEDCB), const Color(0xFF8A5A00));

  static ColorScheme _tintedPrimaryContainer(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? scheme.copyWith(
          primary: const Color(0xFFFF6B1A),
          onPrimary: const Color(0xFF140800),
          primaryContainer: const Color(0xFF351F17),
          // Same orange as `primary`, on purpose. The navigation label takes
          // `primary` while a chip label takes this one, and two shades for
          // the one meaning — "selected" — reads as a mistake.
          onPrimaryContainer: const Color(0xFFFF6B1A),
          secondary: const Color(0xFF4EE1FF),
          onSecondary: const Color(0xFF001B22),
          secondaryContainer: const Color(0xFF15313A),
          onSecondaryContainer: const Color(0xFF4EE1FF),
          tertiary: const Color(0xFFFFB000),
          onTertiary: const Color(0xFF1A1200),
          tertiaryContainer: const Color(0xFF262114),
          onTertiaryContainer: const Color(0xFFFFB000),
          error: const Color(0xFFFF4A3D),
          onError: const Color(0xFF1A0402),
        )
      : scheme.copyWith(
          // Safety orange itself is 2.5:1 on paper, so text takes it burnt:
          // 5.8:1 on the base, 4.8:1 on the selected fill. The brackets keep
          // the bright one, see [_bracket].
          primary: const Color(0xFFA8380A),
          onPrimary: const Color(0xFFFFFFFF),
          primaryContainer: const Color(0xFFE9DBD3),
          onPrimaryContainer: const Color(0xFFA8380A),
          secondary: const Color(0xFF0E7490),
          onSecondary: const Color(0xFFFFFFFF),
          secondaryContainer: const Color(0xFFD7E2E3),
          onSecondaryContainer: const Color(0xFF0B5F76),
          tertiary: const Color(0xFF8A5A00),
          onTertiary: const Color(0xFFFFFFFF),
          tertiaryContainer: const Color(0xFFFCEDCB),
          onTertiaryContainer: const Color(0xFF8A5A00),
          error: const Color(0xFFC92A2A),
          onError: const Color(0xFFFFFFFF),
        );

  /// Corner bracket colour. Decoration, not text, so on paper it can keep the
  /// bright safety orange (3.4:1 on the panel, clear of the 3:1 for graphics).
  static Color _bracket(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? scheme.primary
      : const Color(0xFFE8590C);

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _textTheme(base.textTheme, scheme);
    // Primary actions take the reference's secondary button rather than a
    // solid orange slab: the orange as a faint fill, an orange edge and an
    // orange label — 5.0:1 on dark, 5.3:1 on light. A full-orange FAB was the
    // loudest thing on every screen.
    final dark = scheme.brightness == Brightness.dark;
    final actionFill = Color.alphaBlend(
      scheme.primary.withValues(alpha: dark ? 0.18 : 0.10),
      scheme.surfaceContainerLow,
    );
    final actionInk = scheme.primary;
    final actionEdge = BorderSide(
      color: scheme.primary.withValues(alpha: 0.45),
    );
    return base.copyWith(
      textTheme: text,
      // Transparent so the grid shows; each route paints its own backdrop,
      // see `GridBackdrop`.
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: GridPageTransitionsBuilder.theme(),

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
        // Mono runs wider than the sans it replaced, hence 22 rather than
        // 26 — `BrandTitle` still scales down on narrow phones.
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
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
        shape: BracketBorder(
          side: BorderSide(color: scheme.outlineVariant),
          bracketColor: _bracket(scheme),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
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
        backgroundColor: actionFill,
        foregroundColor: actionInk,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 4,
        iconSize: 26,
        extendedTextStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: actionInk,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: actionEdge,
        ),
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
          backgroundColor: actionFill,
          foregroundColor: actionInk,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ).copyWith(
          // A disabled button loses the edge too, or it still reads as live.
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? BorderSide.none
                : actionEdge,
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
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        shape: BracketBorder(
          side: BorderSide(color: scheme.outlineVariant),
          bracketColor: _bracket(scheme),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
  ///
  /// Headlines, the app bar title and every label are set in the mono face,
  /// as the reference sets its numerals and its spaced-out captions. Titles
  /// and body stay in the sans: they carry names and sentences, and a whole
  /// screen of Vietnamese prose in mono is tiring to read.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    const tabular = [FontFeature.tabularFigures()];
    const mono = MissionStyle.mono;
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: mono,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        fontFeatures: tabular,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: mono,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.5,
        fontFeatures: tabular,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: mono,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
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
        fontFamily: mono,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: mono,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.4,
        color: scheme.onSurfaceVariant,
        fontFeatures: tabular,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: mono,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.4,
        fontFeatures: tabular,
      ),
    );
  }
}
