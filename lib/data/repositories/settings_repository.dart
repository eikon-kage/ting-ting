import '../../models/qr_account.dart';
import '../dao/settings_dao.dart';
import '../data_changes.dart';

/// Lựa chọn của user. Mỗi thứ một khoá, đọc ra kiểu nào thì nói rõ ở đây chứ
/// không để nơi gọi tự đoán chuỗi trong bảng nghĩa là gì.
class SettingsRepository {
  SettingsRepository(this._dao, this._changes);

  /// Bật thông báo tổng kết tuần vào sáng thứ Hai.
  static const String weeklyDigest = 'weekly_digest';

  /// Tài khoản nhận tiền dùng cho màn mã QR, dạng JSON của [QrAccount].
  static const String qrAccount = 'qr_account';

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

  /// Tài khoản màn mã QR điền sẵn lần sau, `null` khi user chưa tạo mã nào.
  Future<QrAccount?> readQrAccount() async {
    final raw = await _dao.read(qrAccount);
    return raw == null ? null : QrAccount.decode(raw);
  }

  /// Không gõ chuông [DataChanges]: đây là chỗ điền sẵn của riêng màn mã QR,
  /// không màn nào khác đọc tới, mà chuông thì kéo mọi controller đang mở tải
  /// lại số liệu.
  Future<void> writeQrAccount(QrAccount account) =>
      _dao.write(qrAccount, account.encode());
}
