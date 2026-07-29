import '../../domain/bank_names.dart';
import '../../domain/bank_parser.dart';
import '../../models/models.dart';
import '../../services/notification_capture.dart';
import 'base_controller.dart';

/// Một dòng nhật ký kèm kết quả bóc tách — bóc sẵn ở controller để mỗi lần vẽ
/// lại danh sách không phải chạy regex lần nữa.
class RawLogEntry {
  const RawLogEntry({
    required this.log,
    required this.parsed,
    required this.sourceEnabled,
  });

  final RawLog log;

  /// `null` khi thông báo này không đọc ra được số tiền.
  final ParseResult? parsed;

  /// App gửi thông báo này đã được bật làm nguồn hay chưa.
  final bool sourceEnabled;

  bool get isTransaction => parsed != null;

  /// Chỉ mời bật nguồn với app thật sự có gửi thông báo dạng giao dịch.
  bool get canBecomeSource => isTransaction && !sourceEnabled;
}

/// Nhật ký mọi notification đi qua máy, kèm kết quả bóc tách.
class RawLogController extends BaseController {
  RawLogController({super.data, NotificationCapture? capture})
    : _capture = capture ?? NotificationCapture.instance;

  final NotificationCapture _capture;

  List<RawLogEntry> _entries = const [];
  bool _onlyTransactions = false;

  bool get onlyTransactions => _onlyTransactions;

  List<RawLogEntry> get entries => _onlyTransactions
      ? _entries.where((e) => e.isTransaction).toList()
      : _entries;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    final logs = await data.rawLogs.recent();
    final enabled = await data.sources.enabledPackages();
    _entries = [
      for (final log in logs)
        RawLogEntry(
          log: log,
          parsed: BankParser.parse(log.title, log.content),
          sourceEnabled: enabled.contains(log.packageName),
        ),
    ];
  });

  void toggleFilter() {
    _onlyTransactions = !_onlyTransactions;
    notify();
  }

  /// Thêm app gửi thông báo này làm nguồn rồi bật luôn.
  /// Trả về tên nguồn và số giao dịch dựng lại được, `null` nếu thất bại.
  Future<({String name, int imported})?> enableSourceFor(RawLog log) async {
    final source = await data.sources.registerCandidate(
      Source(
        packageName: log.packageName,
        displayName: suggestedBankName(log.packageName),
        enabled: false,
      ),
    );
    if (source == null) return null;
    final imported = await _capture.enableSourceAndBackfill(source);
    return (name: source.displayName, imported: imported);
  }
}
