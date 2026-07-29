import '../../models/models.dart';
import '../../services/notification_capture.dart';
import 'base_controller.dart';

/// Danh sách app được coi là nguồn giao dịch.
class SourcesController extends BaseController {
  SourcesController({super.data, NotificationCapture? capture})
    : _capture = capture ?? NotificationCapture.instance;

  final NotificationCapture _capture;

  List<Source> _sources = const [];

  List<Source> get sources => _sources;
  List<Source> get enabled => _sources.where((s) => s.enabled).toList();
  List<Source> get pending => _sources.where((s) => !s.enabled).toList();
  bool get isEmpty => _sources.isEmpty;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _sources = await data.sources.all();
  });

  /// Bật nguồn thì dựng lại luôn giao dịch từ nhật ký cũ.
  /// Trả về số giao dịch vừa dựng lại để màn hình báo cho user.
  Future<int> setEnabled(Source source, {required bool enabled}) async {
    if (!enabled) {
      await data.sources.setEnabled(source.packageName, enabled: false);
      return 0;
    }
    return _capture.enableSourceAndBackfill(source);
  }

  Future<void> rename(Source source, String displayName) =>
      data.sources.rename(source.packageName, displayName);
}
