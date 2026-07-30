import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color, DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/money.dart';
import '../data/data_store.dart';
import '../models/models.dart';

/// Mã các nút bấm trên thông báo giao dịch.
///
/// Android chỉ hiện tối đa ba nút nên phải chọn: ghi chú (gõ thẳng trên thông
/// báo), không tính (gạt khỏi Thu–Chi) và sửa (mở app vào đúng giao dịch, ở đó
/// đủ chỗ cho nhóm, thu/chi, sổ nợ, ví...).
class AlertAction {
  static const String note = 'note';
  static const String exclude = 'exclude';
  static const String edit = 'edit';
}

const String _channelId = 'txn_alerts';
const String _channelName = 'Giao dịch mới';

/// Màu accent của thông báo, trùng `primary` của scheme tối trong app.
const Color _accent = Color(0xFF5B9CD6);

/// Thông báo xác nhận đã lưu ghi chú nằm lại chừng này rồi tự tắt.
const int _confirmTimeoutMs = 6000;

/// Bắn thông báo cho mỗi giao dịch mới, kèm nút thao tác nhanh.
///
/// "Ghi chú" và "Không tính" chạy ngầm, không mở app — kể cả khi app đã bị
/// tắt hẳn (xem [onBackgroundResponse]). "Sửa" thì phải mở app.
class TxnAlerts {
  TxnAlerts._();

  static final TxnAlerts instance = TxnAlerts._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Payload của lời nhắc tổng kết tuần. Không phải id giao dịch nào, nên nó
  /// được nhận ra trước khi payload bị đọc thành số.
  static const String digestPayload = 'digest';

  /// Giao dịch user muốn xem lại — UI lắng nghe để mở sheet chi tiết.
  final ValueNotifier<int?> pendingEditTxnId = ValueNotifier(null);

  /// User vừa bấm vào lời nhắc tổng kết tuần — UI mở màn "Nhìn lại".
  final ValueNotifier<bool> pendingDigest = ValueNotifier(false);

  bool _ready = false;

  /// Truyền `background: true` khi gọi từ isolate của foreground service: ở đó
  /// không có activity nào để xin quyền, và cũng không có màn hình nào để mở.
  Future<void> init({bool background = false}) async {
    if (_ready || !Platform.isAndroid) return;
    // Icon silhouette chứ không phải icon launcher: small icon chỉ được đọc
    // kênh alpha, ảnh đục kín nền sẽ ra một ô vuông trắng trên thanh trạng thái.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_tingting'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Thông báo mỗi khi ghi nhận một giao dịch mới',
        importance: Importance.defaultImportance,
      ),
    );
    if (!background) {
      await android?.requestNotificationsPermission();

      // App có thể vừa được mở lên bằng chính một nút bấm trên thông báo.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        _onForegroundResponse(response);
      }
    }

    _ready = true;
  }

  Future<void> show(Txn txn) => _showAlert(_plugin, txn);

  Future<void> cancel(int txnId) async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(id: txnId);
  }

  void _onForegroundResponse(NotificationResponse response) {
    if (response.payload == digestPayload) {
      pendingDigest.value = true;
      return;
    }
    final txnId = int.tryParse(response.payload ?? '');
    if (txnId == null) return;
    final action = response.actionId;
    // Bấm vào thân thông báo cũng coi như muốn xem giao dịch.
    if (action == null || action == AlertAction.edit) {
      pendingEditTxnId.value = txnId;
      return;
    }
    unawaited(
      applyAlertAction(
        txnId,
        action,
        input: response.input,
        plugin: _plugin,
      ),
    );
  }
}

/// Chạy trong isolate nền khi user bấm nút mà không mở app.
@pragma('vm:entry-point')
void onBackgroundResponse(NotificationResponse response) {
  // Isolate nền chưa có plugin nào được đăng ký sẵn.
  DartPluginRegistrant.ensureInitialized();
  final txnId = int.tryParse(response.payload ?? '');
  if (txnId == null) return;
  unawaited(applyAlertAction(txnId, response.actionId, input: response.input));
}

/// Áp dụng lựa chọn nhanh lên giao dịch. Dùng chung cho cả hai isolate.
///
/// [input] là chữ user gõ vào ô trả lời nhanh của nút "Ghi chú". [plugin] chỉ
/// có ở isolate chính; isolate nền tự dựng bản của nó khi cần vẽ lại thông báo.
Future<void> applyAlertAction(
  int txnId,
  String? actionId, {
  String? input,
  FlutterLocalNotificationsPlugin? plugin,
}) async {
  final txns = DataStore.instance.txns;
  final txn = await txns.byId(txnId);
  if (txn == null) return;
  switch (actionId) {
    case AlertAction.note:
      final note = input?.trim() ?? '';
      // Ô trả lời nhanh giữ thông báo lại để còn báo kết quả, nên dù bỏ trống
      // vẫn phải tự tay gỡ — không thì nó treo mãi ở trạng thái "đang gửi".
      if (note.isEmpty) {
        await _pluginFor(plugin).cancel(id: txnId);
        return;
      }
      final saved = txn.copyWith(note: note);
      await txns.save(saved);
      await _confirmNote(_pluginFor(plugin), saved);
    case AlertAction.exclude:
      await txns.save(txn.copyWith(needsReview: false, excluded: true));
  }
}

/// Isolate nền không có sẵn bản của [TxnAlerts]; bản dựng tạm ở đây đủ để gọi
/// `show`/`cancel` vì icon mặc định đã được isolate chính lưu lại từ trước.
FlutterLocalNotificationsPlugin _pluginFor(
  FlutterLocalNotificationsPlugin? plugin,
) => plugin ?? FlutterLocalNotificationsPlugin();

Future<void> _showAlert(
  FlutterLocalNotificationsPlugin plugin,
  Txn txn,
) async {
  if (!Platform.isAndroid || txn.id == null) return;
  final body = _alertBody(txn);
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    // Màu tô icon trên thanh trạng thái — `primary` của scheme tối.
    color: _accent,
    actions: const [
      AndroidNotificationAction(
        AlertAction.note,
        'Ghi chú',
        // Giữ thông báo lại: gửi xong còn vẽ đè lên để báo đã lưu.
        cancelNotification: false,
        inputs: [
          AndroidNotificationActionInput(label: 'Ghi chú cho giao dịch này'),
        ],
      ),
      AndroidNotificationAction(AlertAction.exclude, 'Không tính'),
      AndroidNotificationAction(
        AlertAction.edit,
        'Sửa',
        showsUserInterface: true,
      ),
    ],
    styleInformation: BigTextStyleInformation(
      body,
      contentTitle: _alertTitle(txn),
    ),
  );

  await plugin.show(
    id: txn.id!,
    title: _alertTitle(txn),
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: '${txn.id}',
  );
}

/// Vẽ đè lên đúng thông báo cũ để user thấy ghi chú đã vào, rồi tự tắt.
Future<void> _confirmNote(
  FlutterLocalNotificationsPlugin plugin,
  Txn txn,
) async {
  if (!Platform.isAndroid || txn.id == null) return;
  final body = _alertBody(txn);
  final details = AndroidNotificationDetails(
    _channelId,
    _channelName,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    color: _accent,
    // Chỉ là lời xác nhận, đừng kêu thêm lần nữa.
    silent: true,
    onlyAlertOnce: true,
    timeoutAfter: _confirmTimeoutMs,
    styleInformation: BigTextStyleInformation(
      body,
      contentTitle: _alertTitle(txn),
    ),
  );

  await plugin.show(
    id: txn.id!,
    title: _alertTitle(txn),
    body: body,
    notificationDetails: NotificationDetails(android: details),
    payload: '${txn.id}',
  );
}

String _alertTitle(Txn txn) {
  final amount = formatSigned(
    txn.amount,
    isIncome: txn.direction == TxnDirection.income,
  );
  return '$amount · ${txn.bankName}';
}

String _alertBody(Txn txn) {
  final desc = txn.description?.trim();
  final base = desc == null || desc.isEmpty ? txn.category : desc;
  final note = txn.note?.trim();
  return note == null || note.isEmpty ? base : '$base\n📝 $note';
}
