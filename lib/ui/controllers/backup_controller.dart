import '../../core/date_range.dart' as dates;
import '../../core/date_range.dart' show DateRange;
import '../../domain/backup.dart';
import '../../services/backup_files.dart';
import 'base_controller.dart';

/// Kết quả một thao tác sao lưu, để màn hình biết báo gì cho user.
class BackupOutcome {
  const BackupOutcome.done(this.message) : failed = false;
  const BackupOutcome.failed(this.message) : failed = true;

  /// User đóng hộp chọn file giữa chừng — không phải lỗi, không cần báo gì.
  static const BackupOutcome? cancelled = null;

  final String message;
  final bool failed;
}

/// Màn "Sao lưu": đưa dữ liệu ra ngoài và nhận lại.
class BackupController extends BaseController {
  BackupController({super.data, BackupFiles? files})
    : files = files ?? BackupFiles.instance;

  final BackupFiles files;

  bool _includeRawLogs = false;
  bool _busy = false;
  Map<String, int> _counts = const {};

  /// Có chép cả nhật ký thông báo thô vào bản sao lưu không.
  bool get includeRawLogs => _includeRawLogs;

  /// Đang chạy một thao tác — khoá nút để không bấm chồng lên nhau.
  bool get busy => _busy;

  /// Số dòng từng bảng đang có, để user thấy mình đang sao lưu cái gì.
  Map<String, int> get counts => _counts;

  int get txnCount => _counts[_txnsTable] ?? 0;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    final snapshot = await data.backups.create();
    _counts = {
      for (final entry in snapshot.tables.entries) entry.key: entry.value.length,
    };
  });

  void setIncludeRawLogs(bool value) {
    _includeRawLogs = value;
    notify();
  }

  /// Gói toàn bộ dữ liệu rồi mở hộp chia sẻ để user cất ra ngoài máy.
  Future<BackupOutcome?> exportBackup() => _run(() async {
    final snapshot = await data.backups.create(
      includeRawLogs: _includeRawLogs,
    );
    final shared = await files.shareBackup(snapshot);
    if (!shared) return BackupOutcome.cancelled;
    return BackupOutcome.done(
      'Đã tạo bản sao lưu ${snapshot.rowCount} dòng',
    );
  });

  /// Xuất bảng giao dịch. Bỏ trống [month] là xuất cả lịch sử.
  Future<BackupOutcome?> exportCsv({DateTime? month}) => _run(() async {
    final range = month == null ? null : DateRange.month(month);
    final csv = await data.backups.exportCsv(range: range);
    final label = month == null
        ? 'tat-ca'
        : '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final shared = await files.shareCsv(csv, label: label);
    if (!shared) return BackupOutcome.cancelled;
    return const BackupOutcome.done('Đã xuất bảng giao dịch');
  });

  /// Đọc file user chọn và kiểm tra ngay, trước khi hỏi họ nạp kiểu nào —
  /// không ai nên phải chọn "thay thế toàn bộ" rồi mới biết file hỏng.
  Future<BackupData?> pickBackup() async {
    final raw = await files.pickBackup();
    if (raw == null) return null;
    return data.backups.parse(raw);
  }

  Future<BackupOutcome?> restore(
    BackupData backup, {
    required RestoreMode mode,
  }) => _run(() async {
    final report = await data.backups.restore(backup, mode: mode);
    if (report.total == 0) {
      return const BackupOutcome.done('Máy đã có sẵn toàn bộ dữ liệu này');
    }
    return BackupOutcome.done('Đã nạp ${report.total} dòng dữ liệu');
  });

  /// Bọc một thao tác: khoá nút, và biến lỗi thành câu người đọc được thay vì
  /// để ngoại lệ nổ lên giữa màn hình.
  Future<BackupOutcome?> _run(Future<BackupOutcome?> Function() work) async {
    if (_busy) return null;
    _busy = true;
    notify();
    try {
      return await work();
    } on BackupError catch (e) {
      return BackupOutcome.failed(e.message);
    } catch (e) {
      return BackupOutcome.failed('Không hoàn tất được: $e');
    } finally {
      _busy = false;
      notify();
      await refresh();
    }
  }

  /// Các tháng có dữ liệu, để user chọn tháng muốn xuất.
  Future<List<DateTime>> monthsWithData() => data.txns.monthsWithData();

  DateTime get thisMonth => dates.thisMonth;

  static const String _txnsTable = 'txns';
}
