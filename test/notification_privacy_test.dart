import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/notification_privacy.dart';

void main() {
  group('Nhận diện thông báo bị Android giấu nội dung', () {
    test('câu thay thế tiếng Anh của Android 15', () {
      expect(
        isRedactedNotification('Sensitive notification content hidden'),
        isTrue,
      );
    });

    test('câu thay thế tiếng Việt, có dấu lẫn không dấu', () {
      expect(
        isRedactedNotification('Đã ẩn nội dung thông báo nhạy cảm'),
        isTrue,
      );
      expect(
        isRedactedNotification('Da an noi dung thong bao nhay cam'),
        isTrue,
      );
    });

    test('câu thay thế nằm lẫn trong nội dung khác vẫn tính là bị giấu', () {
      expect(
        isRedactedNotification('  VCB: Sensitive content hidden.  '),
        isTrue,
      );
    });

    test('thông báo biến động số dư thật thì không', () {
      expect(
        isRedactedNotification('TK 0123 +500,000 VND luc 09:42 SD 1,200,000'),
        isFalse,
      );
      expect(isRedactedNotification('   '), isFalse);
    });
  });

  group('Lệnh adb cấp quyền', () {
    test('đặt theo uid — đặt theo package thì hệ thống không đọc tới', () {
      expect(
        sensitiveNotificationsAdbCommand,
        'adb shell appops set --uid com.trustsoft.tingting '
        'RECEIVE_SENSITIVE_NOTIFICATIONS allow',
      );
    });

    test('bản dự phòng chỉ khác ở chỗ bỏ --uid', () {
      expect(
        sensitiveNotificationsAdbFallback,
        sensitiveNotificationsAdbCommand.replaceFirst('--uid ', ''),
      );
    });
  });
}
