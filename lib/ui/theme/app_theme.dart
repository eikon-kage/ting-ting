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
/// - `primaryContainer` đúng bằng `#FF6900`, tức chính màu được yêu cầu. Chói
///   khi trải thành mảng nền lớn, nên chỉ còn dùng cho các mảng trang trí nhỏ:
///   avatar hạng mục, huy hiệu app đang ghi nhận, thẻ số dư trang chủ. Chrome
///   đang chọn đã chuyển sang xám ấm — xem [AppTheme.selectedTone]. 4.5:1 với
///   `onPrimaryContainer`, vừa đủ AA.
///
/// Đổi lại nó kéo cả họ `surface` ám cam theo, nên bảng sáng phải đặt lại nền
/// bằng tay — xem [_neutralSurfaces].
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
    _neutralSurfaces(
      ColorScheme.fromSeed(
        seedColor: brand,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
    ),
  );

  /// Thay họ `surface` của bảng sáng bằng thang gần như trung tính.
  ///
  /// `fidelity` sinh nền ám cam khá nặng: `surfaceContainerHigh` ra `#FEE3D8`,
  /// tức hồng đào thấy rõ — mà đúng vai trò đó lát nền cho chip, ô nhập, thanh
  /// điều hướng và mọi khối phụ, nên cả màn hình như bị phủ một lớp cam. Thang
  /// dưới đây giữ nguyên thứ tự đậm dần, chỉ còn chút hơi ấm (chênh lệch giữa
  /// kênh đỏ và kênh lam còn 3–4/255 thay vì 30–40) để không lạnh hẳn sang xám
  /// xanh.
  ///
  /// Chỉ đụng vào nền và chữ trên nền. `primary`, `primaryContainer` cùng các
  /// vai trò nhấn khác vẫn lấy từ hạt giống — cam vẫn là điểm nhấn duy nhất.
  ///
  /// Tương phản trên nền mới: `onSurface` 16:1, `onSurfaceVariant` 7.7:1 (còn
  /// 6.4:1 khi nằm trên `surfaceContainerHighest`) — đều vượt AA.
  static ColorScheme _neutralSurfaces(ColorScheme scheme) => scheme.copyWith(
    surface: const Color(0xFFFDFBFA),
    surfaceBright: const Color(0xFFFDFBFA),
    surfaceDim: const Color(0xFFEDE9E7),
    surfaceContainerLowest: const Color(0xFFFFFFFF),
    surfaceContainerLow: const Color(0xFFFAF7F6),
    surfaceContainer: const Color(0xFFF5F2F0),
    surfaceContainerHigh: const Color(0xFFEFECEA),
    surfaceContainerHighest: const Color(0xFFEAE6E4),
    onSurface: const Color(0xFF221D1B),
    onSurfaceVariant: const Color(0xFF56504D),
    outline: const Color(0xFF857D79),
    outlineVariant: const Color(0xFFE0DBD8),
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
  );

  /// Nền và chữ cho chrome đang ở trạng thái chọn: indicator thanh điều hướng,
  /// chip, segmented button, nút lọc ngày.
  ///
  /// Trước đây mấy chỗ này lát `primaryContainer`, tức cam đặc `#FF6900` ở
  /// nguyên chroma — đọc lâu thì chói. Vì đó là các mảng nền lớn và luôn hiện
  /// trên màn hình, tô nguyên màu nhấn là quá tay; giờ dùng xám ấm đậm hơn nền
  /// một nấc rõ.
  ///
  /// Đánh đổi đã biết: không còn tín hiệu màu cho trạng thái chọn, nên độ đậm
  /// chữ (w700 so với w500) và viền đậm hơn phải gánh phần phân biệt. Đừng hạ
  /// hai thứ đó xuống.
  ///
  /// `primaryContainer` vẫn nguyên cam cho các chỗ trang trí — avatar hạng mục,
  /// huy hiệu app đang ghi nhận, thẻ số dư trang chủ — nên app không mất màu
  /// nhận diện.
  ///
  /// Tương phản chữ trên nền: 9.1:1 ở bảng sáng, 8.4:1 ở bảng tối — đều vượt
  /// AAA cho cỡ chữ thường.
  static (Color background, Color foreground) selectedTone(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
      ? (const Color(0xFF4A3A33), const Color(0xFFEFE1DA))
      : (const Color(0xFFE4DDD8), const Color(0xFF3D332E));

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _textTheme(base.textTheme, scheme);
    final (selectedBg, selectedFg) = selectedTone(scheme);
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
        titleTextStyle: text.titleLarge?.copyWith(
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
        indicatorColor: selectedBg,
        indicatorShape: const StadiumBorder(),
        // Luôn hiện nhãn: ba tab tên tiếng Việt, chỉ nhìn icon rất dễ đoán nhầm.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? selectedFg
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? selectedFg
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
          selectedBackgroundColor: selectedBg,
          selectedForegroundColor: selectedFg,
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: selectedFg,
        ),
        selectedColor: selectedBg,
        checkmarkColor: selectedFg,
        backgroundColor: scheme.surfaceContainerHigh,
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
