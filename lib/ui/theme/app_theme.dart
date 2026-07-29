import 'package:flutter/material.dart';

/// Chủ đề của app: tông cam, chữ to rõ, icon bo tròn.
///
/// Bảng màu dựng từ hạt giống [brand] theo biến thể `fidelity`. Đừng đổi về
/// `tonalSpot` (biến thể mặc định của Material 3): với hạt giống này `tonalSpot`
/// vắt gần hết chroma, sinh `primary` là `#8E4D2E` — tức đúng màu nâu mà app
/// dùng trước khi đổi sang cam, đổi seed mà nhìn vào không thấy khác gì.
///
/// `fidelity` bám sát hạt giống ở các vai trò nhấn:
///
/// - `primary` `#A14000` — 6.5:1 với chữ trắng.
///
/// Đổi lại nó bão hoà quá tay ở hai chỗ, cả hai đều phải đặt lại bằng tay:
///
/// - họ `surface` bị ám cam theo — xem [_neutralSurfaces];
/// - `primaryContainer` ra đúng `#FF6900` — xem [_tintedPrimaryContainer].
///
/// Cả hai đều chỉ hạ độ bão hoà của nền. Cam vẫn là màu nhận diện, chỉ còn ở
/// những mảng nhỏ mà mắt không phải nhìn lâu.
class AppTheme {
  const AppTheme._();

  /// Cam chủ đạo — `oklch(0.705 0.213 47.604)`. Sắc đó nằm ngoài gamut sRGB một
  /// chút; ép về gamut ra `#FF6900`, thực tế là `oklch(0.700 0.202 44.4)`.
  ///
  /// Cố ý nằm ở dải màu ấm, để không đụng trustybot-frontend. Toàn bộ màu có
  /// sắc của app kia nằm trong dải xanh dương–chàm–tím (hue 247°–291°):
  ///
  /// - `primary-500 #5B9CD6` — "Brand blue. Default action color", khai trong
  ///   `design-system/tokens.json`. Đây mới là nguồn có thẩm quyền.
  /// - `--primary #4B74F6` trong `src/css/global.css`, cùng cả thang `--chart-*`.
  /// - `tertiary-500 #6444B8` — accent tím, dùng thưa.
  ///
  /// Cam cách cả ba ít nhất ΔE 30 trên OKLab. Đừng đổi sang tông lạnh: bản tím
  /// khói từng thử chỉ cách được nhiều nhất 18, và nhìn thực tế là ra ngay họ
  /// hàng với app kia.
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
      _blackSurfaces(
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ),
      ),
    ),
  );

  /// Replaces the dark scheme's `surface` family with a black, neutral ramp.
  ///
  /// `fidelity` pulls the dark neutrals toward the seed just as it does the
  /// light ones, so `surface` lands on `#1D100A` and the raised containers on
  /// `#362720`. Those are browns. On a phone they read as a tinted screen
  /// rather than as an app with a dark background.
  ///
  /// The ramp below is black at the bottom with neutral, very slightly cool
  /// steps above it — blue leads red by 2–6/255. That coolness is deliberate
  /// and is the opposite of the light scheme, where the ramp is warm: this is
  /// what a dark finance app looks like, and warmth that reads as "cream" on
  /// white reads as "stained" on black.
  ///
  /// True `#000000` at the base rather than a near-black: it costs nothing,
  /// switches off OLED pixels, and gives the raised containers somewhere to
  /// step up from. Cards, sheets and the navigation bar all sit on
  /// `surfaceContainerLow`, so they lift off the background by fill; the card
  /// border is left as a hairline against black rather than a drawn edge.
  ///
  /// Accents stay warm — `primary` and `primaryContainer` are untouched. Orange
  /// on neutral black is the contrast that carries the brand here; matching the
  /// background to the accent is what made the old scheme look brown.
  ///
  /// Contrast: `onSurface` 18.79:1, `onSurfaceVariant` 10.66:1 on the base and
  /// 7.53:1 on `surfaceContainerHighest`. The chart colours hold up unchanged —
  /// income 10.76:1, expense 9.04:1 against black.
  static ColorScheme _blackSurfaces(ColorScheme scheme) => scheme.copyWith(
    surface: const Color(0xFF000000),
    surfaceDim: const Color(0xFF000000),
    surfaceBright: const Color(0xFF2A2A2E),
    surfaceContainerLowest: const Color(0xFF000000),
    surfaceContainerLow: const Color(0xFF121215),
    surfaceContainer: const Color(0xFF17171B),
    surfaceContainerHigh: const Color(0xFF1F1F24),
    surfaceContainerHighest: const Color(0xFF27272D),
    onSurface: const Color(0xFFF2F2F5),
    onSurfaceVariant: const Color(0xFFB8B8C0),
    outline: const Color(0xFF7A7A85),
    outlineVariant: const Color(0xFF33333A),
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
  /// read. On black that inverts. A mid-dark brown fill — `#5C3620` was tried —
  /// does not read as "tinted", it reads as a stain, and the debt overview card
  /// is a large enough panel to make that obvious. So the dark fill only lifts
  /// one step off the surface ramp and the orange moves into the foreground,
  /// where it sits on a small area and stays sharp.
  ///
  /// That leaves the dark fill nearly level with an unselected chip, 1.15:1, so
  /// it is not carrying selection on its own. The orange label against the grey
  /// one is, backed by w700 and the `outline` border — the same three cues the
  /// light scheme leans on.
  ///
  /// Contrast against `onPrimaryContainer` is 7.51:1 light and 8.43:1 dark.
  static ColorScheme _tintedPrimaryContainer(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? scheme.copyWith(
          primaryContainer: const Color(0xFF332822),
          onPrimaryContainer: const Color(0xFFFFB694),
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
