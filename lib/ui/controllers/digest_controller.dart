import '../../models/models.dart';
import '../../services/digest_alerts.dart';
import 'base_controller.dart';

/// Màn "Nhìn lại": tổng kết tuần và tháng đang diễn ra.
class DigestController extends BaseController {
  DigestController({super.data, DigestAlerts? alerts, DigestPeriod? period})
    : alerts = alerts ?? DigestAlerts.instance,
      _period = period ?? DigestPeriod.week;

  final DigestAlerts alerts;

  DigestPeriod _period;
  Digest? _digest;
  bool _reminderOn = false;

  DigestPeriod get period => _period;

  Digest? get digest => _digest;

  /// Có bật lời nhắc sáng thứ Hai không.
  bool get reminderOn => _reminderOn;

  bool get remindersSupported => alerts.supported;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _digest = await data.reports.digest(_period);
    _reminderOn = await alerts.enabled;
  });

  Future<void> selectPeriod(DigestPeriod value) async {
    if (value == _period) return;
    _period = value;
    await load(() async {
      _digest = await data.reports.digest(_period);
    }, showSpinner: true);
  }

  Future<void> setReminder({required bool enabled}) async {
    _reminderOn = enabled;
    notify();
    await alerts.setEnabled(enabled: enabled);
  }
}
