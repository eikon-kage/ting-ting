import '../../domain/bank_names.dart';
import '../../domain/notification_privacy.dart';
import '../../models/models.dart';
import '../../services/capture_service.dart';
import '../../services/notification_capture.dart';
import 'base_controller.dart';

/// Một app gửi thông báo, nhìn từ màn cấu hình ngân hàng.
class BankTemplateEntry {
  const BankTemplateEntry({
    required this.packageName,
    required this.displayName,
    required this.enabled,
    required this.isSource,
    required this.logCount,
    required this.lastAt,
    required this.hasProfile,
    required this.redacted,
  });

  final String packageName;
  final String displayName;

  /// Đang ghi nhận giao dịch từ app này.
  final bool enabled;

  /// Đã nằm trong bảng nguồn (app từng gửi thông báo đọc ra được tiền).
  final bool isSource;

  final int logCount;
  final DateTime? lastAt;

  /// Đã có mẫu bóc tách riêng.
  final bool hasProfile;

  /// Thông báo mới nhất của app này bị Android giấu nội dung.
  final bool redacted;
}

/// Màn "Ngân hàng": danh sách app gửi thông báo và mẫu bóc tách của từng app.
///
/// Khác màn Nguồn ở chỗ liệt kê cả những app parser chưa đọc nổi — chính chúng
/// mới là những app cần khai mẫu riêng.
class BankTemplatesController extends BaseController {
  BankTemplatesController({
    super.data,
    NotificationCapture? capture,
    CaptureService? service,
  }) : _capture = capture ?? NotificationCapture.instance,
       _service = service ?? CaptureService.instance;

  final NotificationCapture _capture;
  final CaptureService _service;

  List<BankTemplateEntry> _entries = const [];
  bool _capturing = false;

  List<BankTemplateEntry> get entries => _entries;

  /// Foreground service đang chạy — tức là app vẫn đọc được thông báo kể cả
  /// khi user vuốt nó khỏi recents.
  bool get capturing => _capturing;

  bool get captureSupported => _service.supported;

  List<BankTemplateEntry> get active =>
      _entries.where((e) => e.enabled).toList();

  /// App đã gửi thông báo nhưng chưa được bật ghi nhận.
  List<BankTemplateEntry> get others =>
      _entries.where((e) => !e.enabled).toList();

  bool get isEmpty => _entries.isEmpty;

  /// Có app nào đang bị hệ thống giấu nội dung thông báo không.
  bool get hasRedacted => _entries.any((e) => e.redacted);

  Future<void> init() async {
    watchData();
    await refresh();
  }

  /// Bật hoặc tắt hẳn việc theo dõi nền.
  Future<void> setCapturing({required bool enabled}) async {
    if (enabled) {
      // Thiếu quyền thông báo thì service không dựng được, thiếu miễn tối ưu
      // pin thì dựng được nhưng sống không lâu.
      await _service.requestPermissions();
      await _service.enable();
    } else {
      await _service.disable();
    }
    _capturing = await _service.running;
    notify();
  }

  @override
  Future<void> refresh() => load(() async {
    _capturing = await _service.running;
    final sources = await data.sources.all();
    final packages = await data.rawLogs.packages();
    final configured = await data.parserProfiles.configuredPackages();

    final byPackage = {for (final s in sources) s.packageName: s};
    final names = <String>{...byPackage.keys, ...packages.map((p) => p.packageName)};
    final activity = {for (final p in packages) p.packageName: p};

    final entries = [
      for (final packageName in names)
        BankTemplateEntry(
          packageName: packageName,
          displayName:
              byPackage[packageName]?.displayName ??
              suggestedBankName(packageName),
          enabled: byPackage[packageName]?.enabled ?? false,
          isSource: byPackage.containsKey(packageName),
          logCount: activity[packageName]?.count ?? 0,
          lastAt: activity[packageName]?.lastAt,
          hasProfile: configured.contains(packageName),
          redacted: isRedactedNotification(
            activity[packageName]?.lastContent ?? '',
          ),
        ),
    ];
    // App đang ghi nhận lên trước, còn lại xếp theo mức độ ồn ào — app ngân
    // hàng bắn vài thông báo một ngày sẽ nổi lên trên đám app tạp.
    entries.sort((a, b) {
      if (a.enabled != b.enabled) return a.enabled ? -1 : 1;
      return b.logCount.compareTo(a.logCount);
    });
    _entries = entries;
  });

  /// Bật app làm nguồn (tự thêm vào bảng nguồn nếu chưa có) hoặc tắt đi.
  /// Trả về số giao dịch dựng lại được từ nhật ký cũ.
  Future<int> setEnabled(
    BankTemplateEntry entry, {
    required bool enabled,
  }) async {
    if (!enabled) {
      await data.sources.setEnabled(entry.packageName, enabled: false);
      return 0;
    }
    final source =
        await data.sources.registerCandidate(
          Source(
            packageName: entry.packageName,
            displayName: entry.displayName,
            enabled: false,
          ),
        ) ??
        Source(
          packageName: entry.packageName,
          displayName: entry.displayName,
          enabled: false,
        );
    return _capture.enableSourceAndBackfill(source);
  }

  /// Đổi tên hiển thị. App chưa có trong bảng nguồn thì ghi nhận trước, không
  /// thì lệnh đổi tên rơi vào hư không.
  Future<void> rename(BankTemplateEntry entry, String displayName) async {
    if (!entry.isSource) {
      await data.sources.registerCandidate(
        Source(
          packageName: entry.packageName,
          displayName: displayName,
          enabled: false,
        ),
      );
    }
    await data.sources.rename(entry.packageName, displayName);
  }
}
