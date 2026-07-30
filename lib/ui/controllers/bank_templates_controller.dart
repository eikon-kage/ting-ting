import '../../core/app_id.dart';
import '../../domain/bank_names.dart';
import '../../domain/bank_parser.dart';
import '../../domain/notification_privacy.dart';
import '../../models/models.dart';
import '../../services/capture_service.dart';
import '../../services/notification_capture.dart';
import '../../services/summary_widget.dart';
import '../../services/test_notification.dart';
import 'base_controller.dart';

/// Kết quả một lần bắn thông báo thử. Mỗi giá trị là một mắt xích khác nhau
/// của đường đọc thông báo, nên màn hình có thể chỉ đúng chỗ đang hỏng thay vì
/// nói chung chung là "không đọc được".
enum CaptureTestResult {
  /// Thông báo quay về tới nhật ký và parser đọc ra được số tiền — đủ đường.
  parsed,

  /// Về tới nơi nhưng Android đã thay nội dung bằng câu báo ẩn.
  redacted,

  /// Về tới nơi mà parser không tìm ra số tiền nào trong đó.
  unparsed,

  /// Bắn ra rồi nhưng không bao giờ quay lại.
  missed,

  /// Chưa được cấp quyền đọc thông báo — chưa bắn gì cả.
  noPermission,

  /// Theo dõi nền đang tắt, không có ai nghe — chưa bắn gì cả.
  notCapturing,

  /// Không phải Android.
  unsupported,
}

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

  /// Chờ thông báo thử quay lại lâu nhất chừng này. Đường đi qua service của
  /// hệ thống nên gần như tức thì, nhưng máy đang bận thì có thể chậm vài giây.
  static const Duration _testTimeout = Duration(seconds: 8);

  static const Duration _testPollPeriod = Duration(milliseconds: 300);

  final NotificationCapture _capture;
  final CaptureService _service;

  // Singleton, không nhận qua constructor như hai cái trên: constructor của nó
  // là private nên có nhận cũng không dựng được bản giả để test.
  final SummaryWidget _widget = SummaryWidget.instance;

  List<BankTemplateEntry> _entries = const [];
  bool _capturing = false;
  bool _canPinWidget = false;

  List<BankTemplateEntry> get entries => _entries;

  /// Foreground service đang chạy — tức là app vẫn đọc được thông báo kể cả
  /// khi user vuốt nó khỏi recents.
  bool get capturing => _capturing;

  bool get captureSupported => _service.supported;

  /// Hệ thống chịu ghim ô thu chi ra màn hình chính — quyết định có hiện nút
  /// thêm ô hay không.
  bool get canPinWidget => _canPinWidget;

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
    _canPinWidget = await _widget.canPin();
    await refresh();
  }

  /// Bật hộp thoại "thêm ô ra màn hình chính" của hệ thống. Trả về false khi
  /// launcher từ chối — lúc đó chỉ còn cách thêm tay từ khay widget.
  Future<bool> pinWidget() => _widget.pin();

  /// Bắn một thông báo giả rồi chờ xem nó có đi trọn đường về nhật ký không.
  ///
  /// Hai mắt xích đầu hỏi thẳng được nên chặn ngay từ đây: chưa cấp quyền hoặc
  /// theo dõi nền đang tắt thì thông báo chắc chắn không quay lại, mà bắn ra
  /// rồi báo "không đọc được" là đổ oan cho phần đang chạy tốt.
  Future<CaptureTestResult> runCaptureTest() async {
    if (!_capture.supported) return CaptureTestResult.unsupported;
    if (!await _capture.isPermissionGranted()) {
      return CaptureTestResult.noPermission;
    }
    _capturing = await _service.running;
    notify();
    if (!_capturing) return CaptureTestResult.notCapturing;

    final sentAt = await TestNotification.instance.send();
    final log = await _awaitTestLog(sentAt);
    if (log == null) return CaptureTestResult.missed;
    if (isRedactedNotification(log.content)) return CaptureTestResult.redacted;
    return BankParser.parse(log.title, log.content) == null
        ? CaptureTestResult.unparsed
        : CaptureTestResult.parsed;
  }

  /// Chờ thông báo thử hiện ra trong nhật ký.
  ///
  /// Phải hỏi lại database chứ không nghe sự kiện: việc nhận thông báo diễn ra
  /// trong isolate của foreground service, isolate này chỉ thấy được nó qua
  /// những gì bên kia đã ghi xuống.
  Future<RawLog?> _awaitTestLog(DateTime sentAt) async {
    final deadline = DateTime.now().add(_testTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_testPollPeriod);
      final logs = await data.rawLogs.forPackage(appPackage);
      for (final log in logs) {
        if (log.title == TestNotification.title &&
            !log.postTime.isBefore(sentAt)) {
          return log;
        }
      }
    }
    return null;
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
    final names = <String>{
      ...byPackage.keys,
      ...packages.map((p) => p.packageName),
    };
    // Thông báo thử ghi một dòng nhật ký mang tên package của chính app. Nó chỉ
    // để chẩn đoán, đừng để Ting Ting hiện ra như một ngân hàng chờ bật.
    names.removeWhere((packageName) => packageName.startsWith(appPackage));
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
