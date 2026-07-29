import '../../models/models.dart';
import '../dao/source_dao.dart';
import '../data_changes.dart';

/// Danh sách app được coi là nguồn giao dịch.
class SourceRepository {
  SourceRepository(this._dao, this._changes);

  final SourceDao _dao;
  final DataChanges _changes;

  Future<List<Source>> all() => _dao.all();

  Future<Source?> byPackage(String packageName) => _dao.byPackage(packageName);

  Future<Set<String>> enabledPackages() => _dao.enabledPackages();

  /// Ghi nhận một app vừa gửi notification trông giống giao dịch. Giữ nguyên
  /// lựa chọn cũ nếu app đó đã có trong danh sách.
  Future<Source?> registerCandidate(Source source) async {
    await _dao.insertIfAbsent(source);
    return _dao.byPackage(source.packageName);
  }

  Future<void> setEnabled(String packageName, {required bool enabled}) async {
    await _dao.setEnabled(packageName, enabled);
    _changes.markChanged();
  }

  Future<void> rename(String packageName, String displayName) async {
    await _dao.rename(packageName, displayName);
    _changes.markChanged();
  }
}
