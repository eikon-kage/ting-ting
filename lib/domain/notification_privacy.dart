/// Android 15 giấu nội dung những thông báo bị coi là "nhạy cảm" (mã OTP, biến
/// động số dư...) với mọi app đọc thông báo không được cấp quyền riêng. App
/// nhận được đúng một câu thay thế, không còn số tiền lẫn nội dung.
///
/// Không mẫu bóc tách nào cứu được trường hợp này — phải cấp quyền cho app thì
/// text gốc mới về, nên phát hiện sớm để báo user thay vì để họ ngồi sửa regex.
const List<String> _redactedMarkers = [
  'sensitive notification content hidden',
  'sensitive content hidden',
  'nội dung thông báo nhạy cảm đã bị ẩn',
  'đã ẩn nội dung thông báo nhạy cảm',
  'nội dung nhạy cảm đã bị ẩn',
  // Vài ROM đổ chữ không dấu, giữ luôn bản đã bỏ dấu cho chắc.
  'noi dung thong bao nhay cam da bi an',
  'da an noi dung thong bao nhay cam',
  'noi dung nhay cam da bi an',
];

const String sensitiveNotificationsPackage = 'com.trustsoft.tingting';

/// Lệnh cấp quyền qua adb — cách duy nhất hiện có, Android không cho app tự xin.
///
/// Phải set theo **uid** (`--uid`): hệ thống đọc quyền này ở mức uid, đặt theo
/// package thì lệnh chạy xong không báo lỗi gì nhưng thông báo vẫn bị giấu.
const String sensitiveNotificationsAdbCommand =
    'adb shell appops set --uid $sensitiveNotificationsPackage '
    'RECEIVE_SENSITIVE_NOTIFICATIONS allow';

/// Bản dự phòng cho máy báo lỗi với `--uid` (ROM cũ, appops đời trước).
const String sensitiveNotificationsAdbFallback =
    'adb shell appops set $sensitiveNotificationsPackage '
    'RECEIVE_SENSITIVE_NOTIFICATIONS allow';

/// `true` khi nội dung thông báo đã bị hệ thống thay bằng câu báo "đã ẩn".
bool isRedactedNotification(String content) {
  final text = content.trim().toLowerCase();
  if (text.isEmpty) return false;
  return _redactedMarkers.any(text.contains);
}
