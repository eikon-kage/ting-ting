import 'dart:async';

import '../../core/date_range.dart' as dates;
import '../../core/date_range.dart' show DateRange;
import '../../domain/txn_grouping.dart';
import '../../models/models.dart';
import '../../services/capture_service.dart';
import '../../services/notification_capture.dart';
import 'base_controller.dart';

/// Khoảng ngày dựng sẵn cho bộ lọc nhanh của màn thu chi.
///
/// Mỗi lựa chọn tự tính ra hai đầu ngày, nên nhãn và khoảng luôn khớp nhau —
/// không có chuyện chip "Tháng trước" sáng lên mà danh sách lại là tháng khác.
enum DateFilterPreset {
  thisMonth('Tháng này'),
  lastMonth('Tháng trước'),
  last7Days('7 ngày qua'),
  all('Tất cả');

  const DateFilterPreset(this.label);

  final String label;

  /// Hai đầu ngày (bao gồm cả hai) của lựa chọn. `null` là để ngỏ đầu đó.
  (DateTime?, DateTime?) resolve([DateTime? now]) {
    final today = dates.startOfDay(now ?? DateTime.now());
    return switch (this) {
      DateFilterPreset.thisMonth => (
        dates.startOfMonth(today),
        dates.endOfMonth(today),
      ),
      DateFilterPreset.lastMonth => (
        dates.shiftMonth(today, -1),
        dates.endOfMonth(dates.shiftMonth(today, -1)),
      ),
      DateFilterPreset.last7Days => (
        DateTime(today.year, today.month, today.day - 6),
        today,
      ),
      DateFilterPreset.all => (null, null),
    };
  }
}

/// Màn chính: số dư hai ví, tổng thu chi và danh sách giao dịch đang lọc.
class HomeController extends BaseController {
  HomeController({super.data, NotificationCapture? capture, CaptureService? service})
    : capture = capture ?? NotificationCapture.instance,
      service = service ?? CaptureService.instance;

  final NotificationCapture capture;

  /// Foreground service nuôi việc nghe thông báo. Màn hình chỉ có nhiệm vụ
  /// dựng nó dậy nếu nó chết, chứ không tự nghe nữa.
  final CaptureService service;

  /// Gõ tới đâu tìm tới đó, nhưng đợi user ngừng gõ mới hỏi tầng dữ liệu.
  static const Duration _typingPause = Duration(milliseconds: 250);

  /// Danh sách một màn hình, không phải bản xuất dữ liệu: cắt ở đây để lọc
  /// "Tất cả" trên máy nhiều năm giao dịch không kéo hết bảng vào bộ nhớ.
  static const int _maxRows = 2000;

  Timer? _debounce;
  String _query = '';
  DateTime? _from;
  DateTime? _to;
  List<DayGroup> _days = const [];
  TxnTotals _totals = TxnTotals.zero;
  WalletBalances _wallets = WalletBalances.empty;
  bool _permissionGranted = false;

  List<DayGroup> get days => _days;
  TxnTotals get totals => _totals;
  WalletBalances get wallets => _wallets;
  bool get permissionGranted => _permissionGranted;

  String get query => _query;

  /// Ngày bắt đầu / kết thúc đang lọc, `null` là không chặn đầu đó.
  DateTime? get from => _from;
  DateTime? get to => _to;

  bool get hasDateFilter => _from != null || _to != null;
  bool get hasFilter => _query.trim().isNotEmpty || hasDateFilter;
  bool get hasTxns => _days.isNotEmpty;

  /// Chip đang sáng, `null` khi khoảng ngày là do user tự chọn trên lịch.
  DateFilterPreset? get activePreset {
    for (final preset in DateFilterPreset.values) {
      final (start, end) = preset.resolve();
      if (start == _from && end == _to) return preset;
    }
    return null;
  }

  /// Chỉ hiện lời nhắc cấp quyền khi nền tảng có hỗ trợ đọc thông báo.
  bool get needsPermission => capture.supported && !_permissionGranted;
  bool get platformSupported => capture.supported;

  Future<void> init() async {
    // Mở app ra là thấy tháng này, giống nếp cũ; muốn xa hơn thì đổi bộ lọc.
    final (start, end) = DateFilterPreset.thisMonth.resolve();
    _from = start;
    _to = end;
    watchData();
    await refreshPermission();
    await refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Future<void> refresh() => load(_fetch);

  void queryChanged(String value) {
    if (value == _query) return;
    _query = value;
    // Nút xoá từ khoá phải hiện ra ngay khi gõ chữ đầu tiên, không đợi hết
    // khoảng chờ rồi mới nhảy vào.
    notify();
    _debounce?.cancel();
    _debounce = Timer(_typingPause, refresh);
  }

  /// Đặt khoảng ngày. Bỏ trống một đầu là để ngỏ đầu đó, bỏ trống cả hai là
  /// không lọc theo thời gian nữa.
  ///
  /// Nhận ngày thô từ bộ chọn lịch; việc quy về đầu ngày / hết ngày do
  /// [DateRange.spanning] lo.
  void setDateRange({DateTime? from, DateTime? to}) {
    var start = dates.startOfDayOrNull(from);
    var end = dates.startOfDayOrNull(to);
    // Chọn ngược đầu đuôi thì đảo lại — gõ nhầm chứ không phải muốn danh sách
    // rỗng.
    if (start != null && end != null && start.isAfter(end)) {
      (start, end) = (end, start);
    }
    if (start == _from && end == _to) return;
    _from = start;
    _to = end;
    load(_fetch, showSpinner: true);
  }

  void applyPreset(DateFilterPreset preset) {
    final (start, end) = preset.resolve();
    setDateRange(from: start, to: end);
  }

  void clearDateRange() {
    if (!hasDateFilter) return;
    setDateRange();
  }

  Future<void> _fetch() async {
    final txns = await data.txns.search(
      query: _query,
      range: DateRange.spanning(from: _from, to: _to),
      limit: _maxRows,
    );
    _days = groupTxnsByDay(txns);
    _totals = TxnTotals.of(txns);
    _wallets = await data.reports.wallets();
  }

  /// Quyền đọc thông báo do hệ thống quản, phải hỏi lại mỗi lần quay lại app.
  ///
  /// Nhân tiện dựng lại foreground service nếu nó đã bị hệ thống giết — đây là
  /// cơ hội duy nhất để phát hiện, vì lúc đó không còn code nào của app chạy.
  Future<void> refreshPermission() async {
    final granted = await capture.isPermissionGranted();
    if (granted != _permissionGranted) {
      _permissionGranted = granted;
      notify();
    }
    if (granted) await service.ensureRunning();
  }

  Future<void> requestPermission() async {
    await capture.requestPermission();
    await refreshPermission();
  }

  /// User vừa bấm "Cho vay" / "Thu nợ" trên thông báo: lấy giao dịch tương ứng
  /// để màn hình mở sheet gán nợ.
  Future<Txn?> txnById(int id) => data.txns.byId(id);
}
