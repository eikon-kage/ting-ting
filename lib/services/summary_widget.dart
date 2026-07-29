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
  Future<void> init() async {
    if (!supported) return;
    _data.changes.addListener(refresh);
    // Mở lại app sau vài ngày thì "tháng này" đã là tháng khác — đẩy lại số.
    _lifecycle ??= AppLifecycleListener(onResume: refresh);
    await refresh();
  }

  Future<void> dispose() async {
    _data.changes.removeListener(refresh);
    _lifecycle?.dispose();
    _lifecycle = null;
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
        'amount': formatMoney(totals.expense),
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
