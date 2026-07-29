import 'package:flutter/foundation.dart';

import '../../data/data_store.dart';

/// Nền chung cho controller của một màn hình.
///
/// Controller là chỗ duy nhất trong tầng UI được gọi tới repository. Widget chỉ
/// đọc state từ controller và gọi lệnh, không tự truy vấn gì.
abstract class BaseController extends ChangeNotifier {
  BaseController({DataStore? data}) : data = data ?? DataStore.instance;

  @protected
  final DataStore data;

  bool _loading = true;
  bool _disposed = false;
  bool _watching = false;

  /// Đang tải lần đầu (hoặc đang đổi bộ lọc) — màn hình hiện vòng xoay.
  bool get loading => _loading;

  /// Tải lại toàn bộ dữ liệu của màn. Lớp con cài đặt.
  Future<void> refresh();

  /// Nghe chuông "dữ liệu vừa đổi" để tự tải lại sau mỗi lần ghi, kể cả khi
  /// việc ghi xảy ra ở màn khác.
  @protected
  void watchData() {
    if (_watching) return;
    _watching = true;
    data.changes.addListener(refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    if (_watching) data.changes.removeListener(refresh);
    super.dispose();
  }

  /// Bọc một lần tải: tự tắt cờ loading và bỏ qua kết quả nếu màn đã đóng.
  @protected
  Future<void> load(
    Future<void> Function() work, {
    bool showSpinner = false,
  }) async {
    if (showSpinner && !_loading) {
      _loading = true;
      notify();
    }
    try {
      await work();
    } finally {
      _loading = false;
      notify();
    }
  }

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }
}
