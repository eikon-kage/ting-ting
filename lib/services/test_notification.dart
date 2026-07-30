import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

/// A fake bank notification the user can fire on demand.
///
/// Whether the app really reads bank notifications rests on a chain that
/// nothing on screen can show: notification access granted, the foreground
/// service alive, its listener still bound to the system, and Android not
/// redacting the text on the way through. Waiting for a real bank message to
/// find out is slow, and when nothing arrives it says nothing about which link
/// broke. This posts a message shaped like a bank's, and the caller watches the
/// raw log for it to come back round.
class TestNotification {
  TestNotification._();

  static final TestNotification instance = TestNotification._();

  /// Id of the posted notification, and the only mark the capture pipeline has
  /// to tell this one message from our own package apart from the transaction
  /// alerts it must keep ignoring. Deliberately far above any row id in the
  /// transaction table — those are what `TxnAlerts` posts under, so a small
  /// number here would sooner or later land on a real alert.
  static const int notificationId = 990099;

  static const String _channelId = 'test_notification';
  static const String _channelName = 'Thông báo thử';

  /// Title of the posted notification. The listener hands it back verbatim, so
  /// the entry is recognisable in the raw log.
  static const String title = 'Ngân hàng Thử Nghiệm';

  /// Màu accent, trùng `primary` của scheme tối trong app.
  static const Color _accent = Color(0xFF5B9CD6);

  /// Tự tắt sau một phút. Đủ lâu để user kịp nhìn, đủ ngắn để nó không còn nằm
  /// trên thanh trạng thái lúc [NotificationCapture.syncActiveNotifications]
  /// quét lại và ghi thêm một dòng nhật ký nữa.
  static const int _timeoutMs = 60 * 1000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool get supported => Platform.isAndroid;

  /// Shaped like a balance-change message: the amount, the balance and the
  /// description all have to be dug out of it, exactly as for a real bank.
  static String bodyAt(DateTime at) =>
      'TK 0123456789|GD: -55,000VND luc ${DateFormat('dd/MM HH:mm').format(at)}'
      '|SD: 12,345,678VND|ND: Ting Ting kiem tra doc thong bao';

  /// Bắn thông báo, trả về thời điểm đưa nó cho hệ thống — mọi dòng nhật ký từ
  /// lúc đó trở đi chính là thông báo thử quay về.
  ///
  /// Gọi sau [TxnAlerts.init]: plugin và icon mặc định được dựng ở đó.
  Future<DateTime> send() async {
    final at = DateTime.now();
    if (!supported) return at;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description:
            'Thông báo giả dùng để kiểm tra app có đọc được thông báo không',
        importance: Importance.defaultImportance,
      ),
    );

    final body = bodyAt(at);
    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: _accent,
          timeoutAfter: _timeoutMs,
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
      ),
    );
    return at;
  }
}
