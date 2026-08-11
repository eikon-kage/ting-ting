import '../../models/saved_qr.dart';
import '../dao/settings_dao.dart';
import '../data_changes.dart';

/// Lựa chọn của user. Mỗi thứ một khoá, đọc ra kiểu nào thì nói rõ ở đây chứ
/// không để nơi gọi tự đoán chuỗi trong bảng nghĩa là gì.
class SettingsRepository {
  SettingsRepository(this._dao, this._changes);

  /// Bật thông báo tổng kết tuần vào sáng thứ Hai.
  static const String weeklyDigest = 'weekly_digest';

  /// Những mã QR đã tạo, dạng JSON một mảng [SavedQr], mới nhất đứng đầu.
  static const String qrHistory = 'qr_history';

  /// Khoá của bản đầu, hồi màn QR chỉ nhớ được đúng một tài khoản. Máy đã cài
  /// bản đó vẫn còn dữ liệu ở đây và không có gì ghi sang khoá mới, nên vẫn
  /// phải đọc tới.
  static const String _legacyQrAccount = 'qr_account';

  final SettingsDao _dao;
  final DataChanges _changes;

  Future<bool> flag(String key, {bool orElse = false}) async {
    final value = await _dao.read(key);
    if (value == null) return orElse;
    return value == '1';
  }

  Future<void> setFlag(String key, {required bool value}) async {
    await _dao.write(key, value ? '1' : '0');
    _changes.markChanged();
  }

  /// Những mã QR đã tạo, mới nhất đứng đầu. Rỗng khi user chưa tạo mã nào.
  Future<List<SavedQr>> readQrHistory() async {
    final raw = await _dao.read(qrHistory);
    if (raw != null) return SavedQr.decodeList(raw);
    final legacy = await _dao.read(_legacyQrAccount);
    return legacy == null ? const [] : SavedQr.decodeList(legacy);
  }

  /// Không gõ chuông [DataChanges]: danh sách này chỉ màn mã QR đọc tới, mà
  /// chuông thì kéo mọi controller đang mở tải lại số liệu.
  Future<void> writeQrHistory(List<SavedQr> history) =>
      _dao.write(qrHistory, SavedQr.encodeList(history));
}
