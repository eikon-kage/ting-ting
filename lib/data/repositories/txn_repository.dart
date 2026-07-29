import '../../core/date_range.dart';
import '../../models/models.dart';
import '../dao/txn_dao.dart';
import '../data_changes.dart';

/// Giao dịch: đọc theo tháng, tìm kiếm, thêm/sửa/xoá.
///
/// Tầng UI và service chỉ nói chuyện với lớp này, không ai chạm vào SQL.
class TxnRepository {
  TxnRepository(this._dao, this._changes);

  final TxnDao _dao;
  final DataChanges _changes;

  Future<List<Txn>> ofMonth(DateTime month) =>
      _dao.inRange(DateRange.month(month));

  Future<Txn?> byId(int id) => _dao.byId(id);

  Future<List<DateTime>> monthsWithData() => _dao.monthsWithData();

  Future<List<Txn>> search({
    String? query,
    String? category,
    TxnDirection? direction,
    DateRange? range,
    int? minAmount,
    int? maxAmount,
    int limit = 500,
  }) => _dao.search(
    query: query,
    category: category,
    direction: direction,
    range: range,
    minAmount: minAmount,
    maxAmount: maxAmount,
    limit: limit,
  );

  /// Thêm giao dịch mới. Trả về bản đã lưu (đã có `id`), hoặc `null` nếu bị
  /// bỏ qua vì trùng với một giao dịch đã có.
  Future<Txn?> add(Txn txn) async {
    final id = await _dao.insert(txn);
    if (id == 0) return null;
    _changes.markChanged();
    return _dao.byId(id);
  }

  Future<void> save(Txn txn) async {
    await _dao.update(txn);
    _changes.markChanged();
  }

  Future<void> remove(int id) async {
    await _dao.deleteById(id);
    _changes.markChanged();
  }
}
