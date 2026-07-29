import 'dart:async';

import '../../core/date_range.dart';
import '../../domain/txn_grouping.dart';
import '../../models/models.dart';
import 'base_controller.dart';

/// Tìm và lọc giao dịch theo từ khoá, nhóm, thu/chi và khoảng ngày.
class TxnSearchController extends BaseController {
  TxnSearchController({super.data});

  /// Gõ tới đâu tìm tới đó, nhưng đợi user ngừng gõ mới hỏi tầng dữ liệu.
  static const Duration _typingPause = Duration(milliseconds: 250);

  Timer? _debounce;
  Timer? _amountDebounce;
  String _query = '';
  String? _category;
  TxnDirection? _direction;
  DateTime? _from;
  DateTime? _to;
  int? _minAmount;
  int? _maxAmount;
  List<Txn> _results = const [];

  List<Txn> get results => _results;
  String? get category => _category;
  TxnDirection? get direction => _direction;

  /// Ngày bắt đầu / kết thúc đang lọc, `null` là không chặn đầu đó.
  DateTime? get from => _from;
  DateTime? get to => _to;

  /// Chặn dưới / chặn trên của số tiền, `null` là để ngỏ đầu đó. So trên số
  /// tiền tuyệt đối nên "từ 500k" bắt cả khoản thu lẫn khoản chi 500k.
  int? get minAmount => _minAmount;
  int? get maxAmount => _maxAmount;

  bool get hasDateFilter => _from != null || _to != null;
  bool get hasAmountFilter => _minAmount != null || _maxAmount != null;

  int get count => _results.length;

  /// Tổng ròng của kết quả tìm được.
  int get net => netOf(_results);

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountDebounce?.cancel();
    super.dispose();
  }

  @override
  Future<void> refresh() => load(_fetch);

  void queryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(_typingPause, refresh);
  }

  /// Bấm lại chip đang chọn thì bỏ lọc.
  void toggleCategory(String value) {
    _category = _category == value ? null : value;
    load(_fetch, showSpinner: true);
  }

  void toggleDirection(TxnDirection value) {
    _direction = _direction == value ? null : value;
    load(_fetch, showSpinner: true);
  }

  /// Đặt khoảng ngày. Bỏ trống một đầu là để ngỏ đầu đó, bỏ trống cả hai là
  /// không lọc theo thời gian nữa.
  ///
  /// Nhận ngày thô từ bộ chọn lịch; việc quy về đầu ngày / hết ngày do
  /// [DateRange.spanning] lo.
  void setDateRange({DateTime? from, DateTime? to}) {
    var start = startOfDayOrNull(from);
    var end = startOfDayOrNull(to);
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

  void clearDateRange() {
    if (!hasDateFilter) return;
    setDateRange();
  }

  /// Đặt khoảng tiền. Bỏ trống một đầu là để ngỏ đầu đó.
  ///
  /// User đang gõ dở nên phải đợi như ô từ khoá: gõ "500k" mà chạy ngay từ
  /// chữ "5" thì màn hình nhấp nháy ba lần vô ích.
  void setAmountRange({int? min, int? max}) {
    var low = min;
    var high = max;
    // Gõ ngược đầu đuôi thì đảo lại, giống cách khoảng ngày xử lý.
    if (low != null && high != null && low > high) {
      (low, high) = (high, low);
    }
    if (low == _minAmount && high == _maxAmount) return;
    _minAmount = low;
    _maxAmount = high;
    notify();
    _amountDebounce?.cancel();
    _amountDebounce = Timer(_typingPause, refresh);
  }

  void clearAmountRange() {
    if (!hasAmountFilter) return;
    _amountDebounce?.cancel();
    _minAmount = null;
    _maxAmount = null;
    load(_fetch, showSpinner: true);
  }

  Future<void> _fetch() async {
    _results = await data.txns.search(
      query: _query,
      category: _category,
      direction: _direction,
      range: DateRange.spanning(from: _from, to: _to),
      minAmount: _minAmount,
      maxAmount: _maxAmount,
    );
  }
}
