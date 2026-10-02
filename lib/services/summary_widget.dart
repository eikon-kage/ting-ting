import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/date_range.dart' as dates;
import '../core/money.dart';
import '../data/data_store.dart';
import '../models/models.dart';

/// Ô tổng quan ngoài màn hình chính Android (app widget).
///
/// Widget do launcher vẽ nên nó không mở được database của app. Lớp này tính
/// sẵn từng dòng chữ rồi đẩy sang native; bên Kotlin chỉ lưu lại và bơm vào
/// RemoteViews — không có logic tiền nong nào nằm ở tầng nền tảng.
class SummaryWidget {
  SummaryWidget._(this._data);

  static final SummaryWidget instance = SummaryWidget._(DataStore.instance);

  static const MethodChannel _channel = MethodChannel(
    'com.trustsoft.tingting/widget',
  );

  static final DateFormat _clock = DateFormat('HH:mm');

  final DataStore _data;
  AppLifecycleListener? _lifecycle;

  /// Chỉ Android mới có widget màn hình chính.
  bool get supported => Platform.isAndroid;

  /// Gọi một lần lúc khởi động: đẩy số hiện tại rồi bám theo mọi thay đổi.
  ///
  /// Pass `background: true` from the foreground service's isolate. It has to
  /// run there too — a transaction read out of a bank notification while the
  /// app is closed is written by that isolate, and the screen's copy of this
  /// class is not around to hear about it. What it skips there is the lifecycle
  /// watch: the service's engine has no activity attached to it, so it never
  /// resumes and the listener would only ever sit idle.
  Future<void> init({bool background = false}) async {
    if (!supported) return;
    _data.changes.addListener(refresh);
    if (!background) {
      // Mở lại app sau vài ngày thì "tháng này" đã là tháng khác — đẩy lại số.
      _lifecycle ??= AppLifecycleListener(onResume: refresh);
    }
    await refresh();
  }

  Future<void> dispose() async {
    _data.changes.removeListener(refresh);
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Hệ thống có nhận yêu cầu ghim ô ra màn hình chính không. Sai thì đừng hiện
  /// nút mời user bấm vào chỗ không dẫn tới đâu.
  Future<bool> canPin() async {
    if (!supported) return false;
    return await _invoke<bool>('canPin') ?? false;
  }

  /// Nhờ hệ thống hỏi "thêm ô này ra màn hình chính?".
  ///
  /// Cần nút này vì khay chọn widget của HyperOS không liệt kê widget của app
  /// bên thứ ba: không có đường nào khác để đặt ô ra màn hình trên máy Xiaomi.
  Future<bool> pin() async {
    if (!supported) return false;
    return await _invoke<bool>('pin') ?? false;
  }

  Future<T?> _invoke<T>(String method) async {
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      // Không có Activity nào nhận kênh — app đang chạy nền.
      return null;
    } on PlatformException catch (e) {
      debugPrint('lỗi kênh widget khi gọi $method: ${e.message}');
      return null;
    }
  }

  Future<void> refresh() async {
    if (!supported) return;

    final month = dates.thisMonth;
    final totals = TxnTotals.of(await _data.txns.ofMonth(month));
    final wallets = await _data.reports.wallets();
    final hasWallet = wallets.hasBankData || wallets.cash != 0;

    try {
      await _channel.invokeMethod<void>('update', <String, String>{
        'label': 'Đã chi tháng ${month.month}',
        // Số chi đã trừ phần người ta trả lại tiền bill: ứng tiền trả cả bàn
        // rồi được hoàn lại thì phần hoàn không phải tiền mình tiêu. Ô "Thu"
        // bên dưới vẫn là trọn tiền vào, nên nó trừ số này ra không bằng "Còn
        // lại" — cố ý: "Còn lại" là tiền thật đổi trong tháng.
        'amount': formatMoney(totals.netExpense),
        'income': formatMoney(totals.income),
        'net': formatMoney(totals.net),
        'balance': hasWallet
            ? formatMoney(wallets.bankTotal + wallets.cash)
            : '—',
        'updated': _clock.format(DateTime.now()),
      });
    } on MissingPluginException {
      // App đang chạy nền, không Activity nào nhận kênh. Số liệu cũ vẫn nằm
      // trên widget; lần mở app tới sẽ đẩy lại.
    } on PlatformException catch (e) {
      debugPrint('không cập nhật được widget: ${e.message}');
    }
  }
}
