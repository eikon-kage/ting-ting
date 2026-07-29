import '../../domain/bank_parser.dart';
import '../../domain/notification_privacy.dart';
import '../../models/models.dart';
import '../../services/notification_capture.dart';
import 'base_controller.dart';

/// Màn khai mẫu bóc tách cho một ngân hàng.
///
/// Mọi thay đổi được thử ngay trên một thông báo mẫu lấy từ nhật ký: user sửa
/// nhãn, thấy liền số tiền / nội dung đọc ra được đúng chưa rồi mới lưu.
class BankTemplateController extends BaseController {
  BankTemplateController({
    required this.packageName,
    super.data,
    NotificationCapture? capture,
  }) : _capture = capture ?? NotificationCapture.instance,
       _draft = ParserProfile(packageName: packageName);

  final String packageName;
  final NotificationCapture _capture;

  ParserProfile _draft;
  List<RawLog> _samples = const [];
  String _sampleTitle = '';
  String _sampleContent = '';
  bool _dirty = false;

  ParserProfile get draft => _draft;

  /// Thông báo thật của app này, mới nhất trước — dùng làm mẫu để thử.
  List<RawLog> get samples => _samples;

  String get sampleTitle => _sampleTitle;
  String get sampleContent => _sampleContent;

  /// User đã sửa gì chưa (để hỏi trước khi thoát).
  bool get dirty => _dirty;

  /// Kết quả bóc tách thông báo mẫu bằng mẫu đang khai — `null` là chưa đọc ra.
  ParseResult? get preview => BankParser.parse(
    _sampleTitle,
    _sampleContent,
    profile: _draft,
  );

  /// Thông báo mẫu bị Android giấu nội dung: sửa mẫu bóc tách vô ích.
  bool get sampleRedacted => isRedactedNotification(_sampleContent);

  bool get hasSample =>
      _sampleTitle.trim().isNotEmpty || _sampleContent.trim().isNotEmpty;

  /// Regex nào user gõ sai — màn hình tô đỏ đúng ô đó.
  bool get amountPatternValid => BankParser.isValidPattern(_draft.amountPattern);
  bool get balancePatternValid =>
      BankParser.isValidPattern(_draft.balancePattern);
  bool get descPatternValid => BankParser.isValidPattern(_draft.descPattern);

  Future<void> init() async {
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    final saved = await data.parserProfiles.byPackage(packageName);
    _samples = await data.rawLogs.forPackage(packageName);
    _draft = saved ?? ParserProfile(packageName: packageName);
    // Ưu tiên mẫu user chốt lần trước, không có thì lấy thông báo gần nhất.
    if (_draft.sampleContent.isNotEmpty || _draft.sampleTitle.isNotEmpty) {
      _sampleTitle = _draft.sampleTitle;
      _sampleContent = _draft.sampleContent;
    } else if (_samples.isNotEmpty) {
      _sampleTitle = _samples.first.title;
      _sampleContent = _samples.first.content;
    }
  });

  void edit(ParserProfile Function(ParserProfile draft) change) {
    _draft = change(_draft);
    _dirty = true;
    notify();
  }

  void useSample(RawLog log) {
    _sampleTitle = log.title;
    _sampleContent = log.content;
    _dirty = true;
    notify();
  }

  void editSample({String? title, String? content}) {
    _sampleTitle = title ?? _sampleTitle;
    _sampleContent = content ?? _sampleContent;
    _dirty = true;
    notify();
  }

  Future<void> save() async {
    await data.parserProfiles.save(
      _draft.copyWith(sampleTitle: _sampleTitle, sampleContent: _sampleContent),
    );
    _dirty = false;
    notify();
  }

  /// Bỏ mẫu riêng, quay về cách đọc mặc định.
  Future<void> resetToDefault() async {
    await data.parserProfiles.reset(packageName);
    _dirty = false;
    await refresh();
  }

  /// Đọc lại nhật ký cũ bằng mẫu vừa lưu. Trả về số giao dịch dựng thêm được.
  Future<int> reparse() => _capture.reparseSource(packageName);
}
