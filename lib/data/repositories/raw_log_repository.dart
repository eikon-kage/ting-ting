import '../../models/models.dart';
import '../dao/raw_log_dao.dart';

/// Nhật ký thông báo thô. Chỉ để chẩn đoán nên không gõ chuông đổi dữ liệu —
/// ghi log không làm số liệu thu chi thay đổi.
class RawLogRepository {
  RawLogRepository(this._dao);

  /// Log cũ hơn ngần này thì xoá, khỏi phình database.
  static const int retentionDays = 60;

  final RawLogDao _dao;

  Future<void> record(RawLog log) => _dao.insert(log);

  Future<List<RawLog>> recent({int limit = 300}) => _dao.recent(limit: limit);

  Future<List<RawLog>> forPackage(String packageName) =>
      _dao.forPackage(packageName);

  /// Các app đã từng gửi thông báo, kèm số lượng và thông báo mới nhất.
  Future<List<({String packageName, int count, DateTime lastAt, String lastContent})>>
  packages() => _dao.packages();

  Future<void> markParsed(int id) => _dao.markParsed(id);

  Future<void> prune() => _dao.deleteBefore(
    DateTime.now().subtract(const Duration(days: retentionDays)),
  );
}
