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

  /// Bộ màu cho nền sáng.
  static const light = ChartPalette._(
    [
      Color(0xFFEB6834), // cam
      Color(0xFF2A78D6), // xanh dương
      Color(0xFF1BAF7A), // ngọc
      Color(0xFFEDA100), // vàng
      Color(0xFFE87BA4), // hồng
      Color(0xFF008300), // lục
    ],
    Color(0xFF1BAF7A),
    Color(0xFFEB6834),
    Color(0xFF0F7A55),
    Color(0xFFA8431C),
    Color(0xFF9E9E96),
  );

  /// Bộ màu cho nền tối — cùng dải màu nhưng chọn lại độ sáng cho nền đậm.
  static const dark = ChartPalette._(
    [
      Color(0xFFD95926),
      Color(0xFF3987E5),
      Color(0xFF199E70),
      Color(0xFFC98500),
      Color(0xFFD55181),
      Color(0xFF008300),
    ],
    Color(0xFF199E70),
    Color(0xFFD95926),
    Color(0xFF4ECFA0),
    Color(0xFFFF8A5C),
    Color(0xFF8A8A82),
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
