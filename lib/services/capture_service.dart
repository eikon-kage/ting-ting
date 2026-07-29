import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'notification_capture.dart';
import 'txn_alerts.dart';

/// Nuôi việc nghe thông báo trong một isolate riêng do foreground service giữ.
///
/// Vì sao phải vòng vèo thế: plugin đọc thông báo đẩy sự kiện qua một
/// `BroadcastReceiver` đăng ký lúc chạy, ôm sẵn `EventSink` của engine Flutter
/// đang sống. Engine chết theo activity, nên vuốt app khỏi recents là đứt
/// luồng — service của hệ thống vẫn bắn broadcast nhưng không còn ai nghe.
/// Foreground service giữ một engine riêng, độc lập với màn hình, nên luồng
/// còn nguyên.
///
/// Đổi lại phải chịu một thông báo thường trực — Android bắt buộc, không tắt
/// được. Thực ra cũng tiện: nó là đèn báo app còn sống hay đã bị hệ thống giết.
class CaptureService {
  CaptureService._();

  static final CaptureService instance = CaptureService._();

  static const int _serviceId = 2601;
  static const String _stopButtonId = 'stop_capture';

  /// User có muốn theo dõi nền hay không. Phải nhớ được qua các lần mở app,
  /// nếu không thì bấm "Tắt" xong mở app cái nó bật lại ngay.
  static const String _wantedKey = 'capture_wanted';

  /// Quét lại thanh trạng thái mỗi chừng này. Không phải để làm việc — luồng
  /// thông báo tự đẩy tới — mà là lưới an toàn phòng khi hệ thống ngắt kết nối
  /// service đọc thông báo mà không báo gì.
  static const int _resyncPeriodMs = 15 * 60 * 1000;

  bool get supported => Platform.isAndroid;

  Future<bool> get running async =>
      supported && await FlutterForegroundTask.isRunningService;

  /// Khai báo tuỳ chọn cho service. Phải gọi trước mọi lệnh start/stop.
  void configure() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'capture_service',
        channelName: 'Theo dõi thông báo',
        channelDescription:
            'Thông báo thường trực cho biết app đang đọc thông báo ngân hàng',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(_resyncPeriodMs),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        // Điểm mấu chốt của cả tính năng này: vuốt app khỏi recents thì
        // service phải sống tiếp.
        stopWithTask: false,
        allowWakeLock: true,
      ),
    );
  }

  /// Xin hai thứ hệ thống đòi: quyền hiện thông báo, và miễn tối ưu pin (thiếu
  /// cái sau thì Android hay giết service lúc máy để yên lâu).
  Future<void> requestPermissions() async {
    if (!supported) return;
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  /// Mặc định là bật: cài app này lên chính là để nó ghi hộ giao dịch.
  static Future<bool> get wanted async =>
      await FlutterForegroundTask.getData<bool>(key: _wantedKey) ?? true;

  /// User bật theo dõi và muốn nó ở trạng thái đó.
  Future<bool> enable() async {
    await FlutterForegroundTask.saveData(key: _wantedKey, value: true);
    return start();
  }

  /// User tắt hẳn — lần mở app sau không tự bật lại nữa.
  Future<void> disable() async {
    await FlutterForegroundTask.saveData(key: _wantedKey, value: false);
    await stop();
  }

  /// Dựng lại service nếu user chưa tắt hẳn. Gọi mỗi lần app mở hoặc quay lại,
  /// để service bị hệ thống giết còn có đường sống lại.
  Future<void> ensureRunning() async {
    if (!supported || !await wanted) return;
    await start();
  }

  /// Bật theo dõi. Gọi lại khi đang chạy rồi thì không sao, chỉ báo `true`.
  Future<bool> start() async {
    if (!supported) return false;
    configure();
    if (await FlutterForegroundTask.isRunningService) return true;
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      // Android 14+ bắt khai loại. Không có loại nào dành cho việc đọc thông
      // báo nên specialUse là chỗ duy nhất đúng.
      serviceTypes: const [ForegroundServiceTypes.specialUse],
      notificationTitle: 'Đang theo dõi thông báo ngân hàng',
      notificationText: 'Giao dịch vẫn được ghi khi app đóng',
      notificationButtons: const [
        NotificationButton(id: _stopButtonId, text: 'Tắt'),
      ],
      callback: startCaptureTask,
    );
    return result is ServiceRequestSuccess;
  }

  Future<void> stop() async {
    if (!supported) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}

/// Điểm vào của isolate nền. Bắt buộc là hàm cấp cao nhất.
@pragma('vm:entry-point')
void startCaptureTask() {
  FlutterForegroundTask.setTaskHandler(CaptureTaskHandler());
}

/// Vòng đời của isolate nghe thông báo.
///
/// Không có logic nghiệp vụ nào ở đây: nó chỉ dựng lại đúng hai thứ mà trước
/// kia màn hình chính dựng — thông báo giao dịch và luồng đọc notification.
class CaptureTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Khởi động máy xong hệ thống dựng lại service dù user đã tắt hẳn — tự
    // rút lui thay vì bám lại.
    if (starter == TaskStarter.system && !await CaptureService.wanted) {
      await FlutterForegroundTask.stopService();
      return;
    }
    await TxnAlerts.instance.init(background: true);
    await NotificationCapture.instance.start();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(NotificationCapture.instance.syncActiveNotifications());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await NotificationCapture.instance.stop();
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Bấm "Tắt" trên thông báo là tắt hẳn, không phải tạm nghỉ tới lần mở app
    // sau — nên ghi nhớ lựa chọn đó luôn.
    if (id == CaptureService._stopButtonId) {
      unawaited(CaptureService.instance.disable());
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}
