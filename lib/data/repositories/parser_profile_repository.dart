import '../../models/models.dart';
import '../dao/parser_profile_dao.dart';
import '../data_changes.dart';

/// Mẫu bóc tách riêng của từng ngân hàng.
///
/// Mỗi notification đi qua máy đều phải tra mẫu, mà thông báo thì đến liên tục
/// — nên giữ luôn cả bảng trong bộ nhớ (vài chục dòng là cùng) và chỉ nạp lại
/// khi user sửa.
class ParserProfileRepository {
  ParserProfileRepository(this._dao, this._changes);

  final ParserProfileDao _dao;
  final DataChanges _changes;

  Map<String, ParserProfile>? _cache;

  Future<Map<String, ParserProfile>> _profiles() async {
    return _cache ??= {
      for (final profile in await _dao.all()) profile.packageName: profile,
    };
  }

  Future<List<ParserProfile>> all() async =>
      (await _profiles()).values.toList();

  Future<ParserProfile?> byPackage(String packageName) async =>
      (await _profiles())[packageName];

  /// Các app đã có mẫu riêng — màn danh sách gắn nhãn cho dễ nhìn.
  Future<Set<String>> configuredPackages() async =>
      (await _profiles()).keys.toSet();

  Future<void> save(ParserProfile profile) async {
    await _dao.save(profile);
    _cache = null;
    _changes.markChanged();
  }

  /// Xoá mẫu riêng — app đó quay về bóc tách theo cách mặc định.
  Future<void> reset(String packageName) async {
    await _dao.delete(packageName);
    _cache = null;
    _changes.markChanged();
  }
}
