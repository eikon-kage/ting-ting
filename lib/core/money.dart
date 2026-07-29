import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.decimalPattern('vi');

/// 1234567 -> "1.234.567 đ"
String formatMoney(int amount) => '${_money.format(amount)} đ';

/// Có dấu +/- phía trước, dùng cho danh sách giao dịch.
String formatSigned(int amount, {required bool isIncome}) =>
    '${isIncome ? '+' : '-'}${formatMoney(amount)}';

/// Rút gọn cho trục biểu đồ: 1.500.000 -> "1,5tr", 250.000 -> "250k".
String formatCompact(int amount) {
  final abs = amount.abs();
  if (abs >= 1000000) {
    final millions = amount / 1000000;
    final text = millions.abs() >= 10
        ? millions.round().toString()
        : millions.toStringAsFixed(1).replaceAll('.', ',');
    return '${text}tr';
  }
  if (abs >= 1000) return '${(amount / 1000).round()}k';
  return '$amount';
}

/// Đọc số tiền user gõ vào ô nhập: bỏ mọi ký tự không phải chữ số.
int parseAmount(String raw) =>
    int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

/// Như [parseAmount] nhưng hiểu thêm lối viết tắt quen tay: "500k", "1tr",
/// "1,5tr", "2m". Gõ đủ sáu số 0 trên bàn phím điện thoại thì ai cũng nản.
///
/// Trả `null` khi ô trống hoặc gõ ra thứ không đọc được — chỗ gọi hiểu là
/// "không lọc" chứ không phải "lọc số 0".
int? parseAmountInput(String raw) {
  final text = raw.trim().toLowerCase();
  if (text.isEmpty) return null;
  final match = RegExp(r'^([\d.,]+)\s*(k|tr|m|)$').firstMatch(text);
  if (match == null) return null;
  final number = match.group(1)!;
  final unit = match.group(2)!;
  // Không có đuôi thì mọi dấu chấm phẩy đều là dấu phân cách hàng nghìn:
  // "1.234.567" phải ra một triệu hai, không phải một phẩy hai.
  if (unit.isEmpty) return int.tryParse(number.replaceAll(RegExp(r'[^\d]'), ''));
  // Có đuôi thì ngược lại, dấu ấy là dấu thập phân: "1,5tr" = 1.500.000.
  final value = double.tryParse(number.replaceAll(',', '.'));
  if (value == null) return null;
  return (value * (unit == 'k' ? 1000 : 1000000)).round();
}
