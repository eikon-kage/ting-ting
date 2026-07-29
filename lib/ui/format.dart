import 'package:intl/intl.dart';

export '../core/money.dart';

final DateFormat _dayFormat = DateFormat('dd/MM/yyyy');
final DateFormat _timeFormat = DateFormat('HH:mm');

String formatDay(DateTime d) => _dayFormat.format(d);
String formatTime(DateTime d) => _timeFormat.format(d);

String formatMonth(DateTime d) => 'Tháng ${d.month}/${d.year}';

/// "T7/26" — nhãn ngắn cho trục biểu đồ theo tháng.
String formatMonthShort(DateTime d) =>
    'T${d.month}/${d.year.toString().substring(2)}';

/// "Hôm nay" / "Hôm qua" / "Thứ Hai, 28/07/2026"
String formatDayHeader(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return '${_weekdays[d.weekday]!}, ${formatDay(d)}';
}

const Map<int, String> _weekdays = {
  DateTime.monday: 'Thứ Hai',
  DateTime.tuesday: 'Thứ Ba',
  DateTime.wednesday: 'Thứ Tư',
  DateTime.thursday: 'Thứ Năm',
  DateTime.friday: 'Thứ Sáu',
  DateTime.saturday: 'Thứ Bảy',
  DateTime.sunday: 'Chủ Nhật',
};
