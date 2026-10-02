import 'dart:async';
import 'dart:io';

// `foundation` cũng có một lớp tên Category (chú thích cho dartdoc), che đi để
// tên nhóm của app không bị lẫn.
import 'package:flutter/foundation.dart' hide Category;
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../core/app_id.dart';
import '../data/data_store.dart';
import '../domain/bank_names.dart';
import '../domain/bank_parser.dart';
import '../domain/txn_factory.dart';
import '../models/models.dart';
import 'notification_event_mapping.dart';
import 'pending_notifications.dart';
import 'test_notification.dart';
import 'txn_alerts.dart';

/// Nghe notification hệ thống, bóc tách giao dịch rồi nhờ tầng dữ liệu lưu lại.
///
/// Chỉ chạy trên Android — iOS không cho app đọc notification của app khác.
/// Lớp này không biết dữ liệu nằm ở đâu: nó chỉ ghép mảnh nền tảng (stream
/// notification) với tầng domain (parser) và repository.
class NotificationCapture {
  NotificationCapture._(this._data);

  static final NotificationCapture instance = NotificationCapture._(
    DataStore.instance,
  );

  /// Quét lại thanh trạng thái chỉ bắn thông báo cho giao dịch mới chừng này
  /// đổ lại. Cũ hơn thì coi như user đã biết rồi — mở app sau một ngày mà bị
  /// dội mười cái thông báo thì phiền hơn là có ích.
  static const Duration _freshWindow = Duration(minutes: 30);

  final DataStore _data;
  StreamSubscription<ServiceNotificationEvent>? _sub;

  bool get supported => Platform.isAndroid;

  Future<bool> isPermissionGranted() async {
    if (!supported) return false;
    return NotificationListenerService.isPermissionGranted();
  }

  /// Mở màn hình Notification access của hệ thống cho user tự bật.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    return NotificationListenerService.requestPermission();
  }

  Future<void> start() async {
    if (!supported || _sub != null) return;
    _sub = NotificationListenerService.notificationsStream.listen(
      _handle,
      onError: (Object e) => debugPrint('notification stream error: $e'),
    );
    await _data.rawLogs.prune();
    await drainQueued();
    await syncActiveNotifications();
  }

  /// Xử lý những thông báo mà listener native đã kịp ghi ra đĩa lúc không có
  /// engine Dart nào sống.
  ///
  /// Đây là đường duy nhất cứu được thông báo đến sau khi user vuốt app khỏi
  /// recents: HyperOS giết process, foreground service không dựng lại được, nên
  /// luồng trực tiếp của plugin không còn ai nghe. Xem [PendingNotifications].
  Future<void> drainQueued() async {
    if (!supported) return;
    final queued = await PendingNotifications.instance.drain();
    if (queued.isEmpty) return;
    final cutoff = DateTime.now().subtract(_freshWindow);
    for (final event in queued) {
      final postTime = event.timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
          : null;
      await _handle(
        event,
        notify: postTime != null && postTime.isAfter(cutoff),
      );
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Quét các notification còn đang hiển thị trên thanh trạng thái — vớt lại
  /// những giao dịch xảy ra lúc app chưa nghe.
  ///
  /// Gọi lúc bắt đầu nghe, và định kỳ từ [CaptureService] để phòng trường hợp
  /// hệ thống ngắt kết nối service đọc thông báo mà không báo gì.
  Future<void> syncActiveNotifications() async {
    try {
      final active = await _activeNotifications();
      final cutoff = DateTime.now().subtract(_freshWindow);
      for (final event in active) {
        // Giao dịch vừa xảy ra thì vẫn bắn thông báo — đây đúng là trường hợp
        // app bị giết, mở lại và thông báo ngân hàng còn nằm trên thanh trạng
        // thái. Cái cũ hơn thì lặng lẽ ghi vào sổ.
        final postTime = event.timestamp > 0
            ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
            : null;
        await _handle(
          event,
          notify: postTime != null && postTime.isAfter(cutoff),
        );
      }
    } catch (e) {
      debugPrint('backfill failed: $e');
    }
  }

  /// What is still sitting on the status bar.
  ///
  /// Not `NotificationListenerService.getActiveNotifications()`: its native
  /// side omits the `haveExtraPicture` key on this path, and
  /// `ServiceNotificationEvent.fromMap` assigns that key straight into a
  /// non-nullable `bool`. Every row therefore throws "type 'Null' is not a
  /// subtype of type 'bool'", the plugin only catches `PlatformException`, and
  /// the whole list dies on its first element — [syncActiveNotifications] never
  /// recovered a single notification, it just logged `backfill failed` each
  /// time. Read the channel directly and build the events here instead.
  Future<List<ServiceNotificationEvent>> _activeNotifications() async {
    final raw = await methodeChannel.invokeMethod<List<dynamic>>(
      'getActiveNotifications',
    );
    return notificationEventsFrom(raw);
  }

  Future<void> _handle(
    ServiceNotificationEvent event, {
    bool notify = true,
  }) async {
    // Bỏ qua sự kiện gỡ notification và các notification thường trực
    // (thanh nhạc, đang tải file...) — không phải giao dịch.
    if (event.hasRemoved || event.onGoing) return;

    final packageName = event.packageName;
    if (packageName.isEmpty) return;
    // Thông báo của chính app không phải giao dịch — thả vào đây thì mỗi thông
    // báo giao dịch lại đẻ ra một giao dịch mới. Ngoại lệ duy nhất là thông báo
    // thử, thứ sinh ra để chứng minh đúng con đường này còn thông.
    final isTest = _isTestNotification(event);
    if (packageName.startsWith(appPackage) && !isTest) return;

    final title = event.title;
    final content = event.content;
    if (title.isEmpty && content.isEmpty) return;

    final postTime = event.timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
        : DateTime.now();

    final profile = await _data.parserProfiles.byPackage(packageName);
    final parsed = BankParser.parse(title, content, profile: profile);

    await _data.rawLogs.record(
      RawLog(
        packageName: packageName,
        title: title,
        content: content,
        postTime: postTime,
        parsed: false,
      ),
    );

    // Thông báo thử xong việc ngay khi vào được nhật ký. Đi tiếp nữa là ghi
    // chính app này vào bảng ngân hàng và nhét một giao dịch bịa vào sổ.
    if (isTest) return;

    if (parsed == null) return;

    // Notification này trông như một giao dịch -> đề xuất app đó làm nguồn.
    final source = await _data.sources.registerCandidate(
      Source(
        packageName: packageName,
        displayName: suggestedBankName(packageName),
        enabled: false,
      ),
    );
    if (source == null || !source.enabled) return;

    await _importTxn(
      packageName: packageName,
      bankName: source.displayName,
      title: title,
      content: content,
      postTime: postTime,
      parsed: parsed,
      notify: notify,
    );
  }

  /// Thông báo thử do chính app bắn ra. Id là dấu hiệu duy nhất phân biệt nó
  /// với thông báo giao dịch, nên phải xét kèm cả tên package: app khác hoàn
  /// toàn có thể dùng trùng con số đó.
  bool _isTestNotification(ServiceNotificationEvent event) =>
      event.id == TestNotification.notificationId &&
      event.packageName.startsWith(appPackage);

  /// Trả về `true` nếu giao dịch được ghi mới (không phải bản trùng).
  Future<bool> _importTxn({
    required String packageName,
    required String bankName,
    required String title,
    required String content,
    required DateTime postTime,
    required ParseResult parsed,
    List<Rule>? userRules,
    List<Category>? categories,
    bool notify = true,
  }) async {
    final rules = userRules ?? await _data.rules.all();
    final groups = categories ?? await _data.categories.all();
    final saved = await _data.txns.add(
      TxnFactory.fromNotification(
        packageName: packageName,
        bankName: bankName,
        title: title,
        content: content,
        postTime: postTime,
        parsed: parsed,
        userRules: rules,
        categories: groups,
      ),
    );
    if (saved == null) return false;
    if (notify) {
      await TxnAlerts.instance.show(
        saved,
        repayment: await _data.repayments.matchFor(saved),
      );
    }
    return true;
  }

  /// Bật một nguồn rồi dựng lại giao dịch từ nhật ký thô đã lưu, để những
  /// notification đến trước lúc bật không bị mất.
  Future<int> enableSourceAndBackfill(Source source) async {
    await _data.sources.setEnabled(source.packageName, enabled: true);
    return _rebuildFromLogs(source);
  }

  /// Đọc lại toàn bộ nhật ký của một nguồn bằng mẫu bóc tách hiện tại.
  ///
  /// Gọi sau khi user sửa mẫu ở màn "Ngân hàng": những thông báo trước đó
  /// parser chịu thua nay đọc ra được sẽ thành giao dịch. Giao dịch đã có
  /// không bị nhân đôi — tầng dữ liệu chặn theo dấu vân tay.
  Future<int> reparseSource(String packageName) async {
    final source = await _data.sources.byPackage(packageName);
    if (source == null || !source.enabled) return 0;
    return _rebuildFromLogs(source);
  }

  Future<int> _rebuildFromLogs(Source source) async {
    final logs = await _data.rawLogs.forPackage(source.packageName);
    final rules = await _data.rules.all();
    final categories = await _data.categories.all();
    final profile = await _data.parserProfiles.byPackage(source.packageName);
    var imported = 0;
    for (final log in logs) {
      final parsed = BankParser.parse(log.title, log.content, profile: profile);
      if (parsed == null) continue;
      final created = await _importTxn(
        packageName: log.packageName,
        bankName: source.displayName,
        title: log.title,
        content: log.content,
        postTime: log.postTime,
        parsed: parsed,
        userRules: rules,
        categories: categories,
        notify: false,
      );
      if (created) {
        imported++;
        if (log.id != null) await _data.rawLogs.markParsed(log.id!);
      }
    }
    return imported;
  }
}
