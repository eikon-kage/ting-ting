import '../../core/date_range.dart' as dates;
import '../../models/models.dart';
import 'base_controller.dart';

/// Màn Báo cáo. Toàn bộ số liệu lấy một lần từ repository báo cáo.
class StatsController extends BaseController {
  /// Bỏ trống [month] thì mở ở tháng này — tab Báo cáo tự đứng một mình, không
  /// có màn nào truyền tháng vào cho.
  StatsController({DateTime? month, super.data})
    : _month = month ?? dates.thisMonth;

  DateTime _month;
  MonthReport _report = MonthReport.empty;

  DateTime get month => _month;
  MonthReport get report => _report;
  bool get showingCurrentMonth => dates.isCurrentMonth(_month);

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(_fetch);

  void shiftMonth(int delta) {
    _month = dates.shiftMonth(_month, delta);
    load(_fetch, showSpinner: true);
  }

  Future<void> _fetch() async {
    _report = await data.reports.monthReport(_month);
  }
}
