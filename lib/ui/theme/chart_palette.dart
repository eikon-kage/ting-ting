import 'package:flutter/material.dart';

/// Bảng màu cho biểu đồ và các con số thu/chi.
///
/// Hai bộ màu sáng/tối được chọn riêng chứ không phải lật ngược lẫn nhau, và
/// đã kiểm bằng validator: nằm trong dải sáng cho phép, đủ độ bão hoà, và các
/// cặp cạnh nhau vẫn phân biệt được với người mù màu (ΔE ≥ 8 trên OKLab).
/// Đừng thêm màu tuỳ hứng — quá 6 nhóm thì gộp vào "Khác".
///
/// Cam đứng đầu vì cam là màu của khoản chi ([expenseMark]), không phải vì nó
/// là màu chủ đạo của app. Biểu đồ tròn ở màn Báo cáo vẽ *chi* theo nhóm, nên
/// nhóm lớn nhất phải ăn theo màu "chi". Đổi tông app thì đừng đụng tới thứ tự
/// này: bảng màu ở đây mang nghĩa thu/chi, không phải mang nhãn thương hiệu.
class ChartPalette {
  const ChartPalette._(this._series, this.incomeMark, this.expenseMark,
      this.incomeText, this.expenseText, this.other);

  /// Light set: the ARES hues darkened for paper. Marks clear 3:1 on the
  /// base except amber (3.0:1), text colours clear 4.5:1. Adjacent pairs sit
  /// at ΔE ≥ 13 on OKLab, deuteranopia and protanopia included.
  static const light = ChartPalette._(
    [
      Color(0xFFE8590C), // orange
      Color(0xFF0A8FB3), // cyan
      Color(0xFFB57A00), // amber
      Color(0xFFD6336C), // pink
      Color(0xFF7048E8), // violet
      Color(0xFF495057), // slate
    ],
    Color(0xFF0A8FB3),
    Color(0xFFE8590C),
    Color(0xFF0E7490),
    Color(0xFFB23C0A),
    Color(0xFF9A9EA5),
  );

  /// Dark set, from the ARES palette: expense is its safety orange, income
  /// its data cyan. The other slots extend it with hues it lacks. Adjacent
  /// pairs sit at ΔE ≥ 16.9 on OKLab, deuteranopia and protanopia included.
  static const dark = ChartPalette._(
    [
      Color(0xFFFF6B1A), // orange
      Color(0xFF4EE1FF), // cyan
      Color(0xFFFFB000), // amber
      Color(0xFFFF5C8A), // pink
      Color(0xFFA98BFF), // lavender
      Color(0xFFD8D6D2), // off-white
    ],
    Color(0xFF4EE1FF),
    Color(0xFFFF6B1A),
    Color(0xFF4EE1FF),
    Color(0xFFFF8A4C),
    Color(0xFF5B6068),
  );

  final List<Color> _series;

  /// Màu khối cho cột "Thu" / "Chi" trong biểu đồ.
  final Color incomeMark;
  final Color expenseMark;

  /// Màu cho số tiền hiển thị dạng chữ — đậm hơn để đủ tương phản khi đọc.
  final Color incomeText;
  final Color expenseText;

  /// Màu trung tính cho nhóm "Khác".
  final Color other;

  static ChartPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Số nhóm tối đa được tô màu riêng; phần dư gom vào "Khác".
  int get maxSlots => _series.length;

  /// Màu theo thứ tự cố định — nhóm thứ n luôn nhận đúng màu thứ n, không xoay
  /// vòng, để lọc bớt nhóm không làm đổi màu những nhóm còn lại.
  Color series(int index) =>
      index < _series.length ? _series[index] : other;
}
