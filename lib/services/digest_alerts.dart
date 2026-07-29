import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/data_store.dart';
import 'txn_alerts.dart';

/// Nhắc xem lại tuần vừa rồi vào sáng thứ Hai.
///
/// Thông báo cố tình không mang con số nào. Nó được hệ thống hẹn giờ từ trước,
/// nên chữ trong đó là chữ viết lúc hẹn — đưa số tiền vào là hứa một con số có
/// thể đã cũ mấy ngày. Nó chỉ mở màn "Nhìn lại", nơi số liệu được tính tại chỗ.
class DigestAlerts {
  DigestAlerts._(this._data);

  static final DigestAlerts instance = DigestAlerts._(DataStore.instance);

  static const String _channelId = 'weekly_digest';
  static const String _channelName = 'Tổng kết tuần';

  /// Id riêng, không đụng vào dải id của thông báo giao dịch (vốn là id giao
  /// dịch trong database).
  static const int _notificationId = -1;

  /// Sáng thứ Hai, sau giờ ngủ dậy và trước giờ vào việc.
  static const int _hour = 8;

  final DataStore _data;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _zonesReady = false;

  bool get supported => Platform.isAndroid;

  /// Gọi sau [TxnAlerts.init] — kênh thông báo đã được khởi tạo ở đó.
  Future<void> init() async {
    if (!supported) return;
    final wanted = await _data.settings.flag(
      SettingsRepository.weeklyDigest,
      orElse: true,
    );
    await setEnabled(enabled: wanted, remember: false);
  }

  /// Bật hoặc tắt lời nhắc. [remember] tắt đi khi chỉ đang áp lại lựa chọn đã
  /// lưu, để không ghi ngược vào database mỗi lần mở app.
  Future<void> setEnabled({
    required bool enabled,
    bool remember = true,
  }) async {
    if (remember) {
      await _data.settings.setFlag(
        SettingsRepository.weeklyDigest,
        value: enabled,
      );
    }
    if (!supported) return;
    if (!enabled) {
      await _plugin.cancel(id: _notificationId);
      return;
    }
    await _schedule();
  }

  Future<bool> get enabled =>
      _data.settings.flag(SettingsRepository.weeklyDigest, orElse: true);

  Future<void> _schedule() async {
    await _prepareZones();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Nhắc xem lại chi tiêu tuần vừa rồi',
        importance: Importance.defaultImportance,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Nhìn lại tuần qua',
        body: 'Tuần rồi tiền đi đâu — xem trong một phút.',
        scheduledDate: _nextMonday(),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        // Hẹn giờ chính xác cần quyền riêng từ Android 12; kiểu này không cần,
        // đổi lại hệ thống được phép dời vài phút. Một lời nhắc đọc lúc nào
        // cũng được thì không đáng đi xin thêm quyền.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: TxnAlerts.digestPayload,
      );
    } on PlatformException catch (e) {
      debugPrint('không hẹn được lời nhắc tổng kết: ${e.message}');
    }
  }

  /// Thứ Hai gần nhất còn ở phía trước, lúc [_hour] giờ.
  tz.TZDateTime _nextMonday() {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, _hour);
    while (next.weekday != DateTime.monday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// Bảng múi giờ phải nạp trước khi dựng được [tz.TZDateTime]. Máy đặt múi
  /// giờ nào thì hẹn theo múi giờ đó — không phải ai cũng ở Việt Nam.
  Future<void> _prepareZones() async {
    if (_zonesReady) return;
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      // Không đọc được tên múi giờ thì cứ để mặc định của thư viện, lời nhắc
      // lệch vài tiếng vẫn hơn là không có.
      debugPrint('không đọc được múi giờ máy: $e');
    }
    _zonesReady = true;
  }
}
