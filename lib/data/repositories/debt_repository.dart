import '../../models/models.dart';
import '../dao/txn_dao.dart';
import '../data_changes.dart';

/// Sổ nợ. Khoản nợ vẫn là một dòng trong bảng giao dịch, chỉ khác ở chỗ nó
/// không được tính vào Thu–Chi.
class DebtRepository {
  DebtRepository(this._dao, this._changes);

  final TxnDao _dao;
  final DataChanges _changes;

  Future<DebtOverview> overview() async {
    final people = await _dao.debtBalances();
    final unassigned = await _dao.debtTxnsWithoutPerson();
    return DebtOverview(people: people, unassigned: unassigned);
  }

  Future<List<Txn>> historyFor(String person) => _dao.debtTxnsFor(person);

  /// Tên người đã từng dùng, để gợi ý khi gán nợ.
  Future<List<String>> knownPeople() => _dao.knownPeople();

  /// Ghi thẳng một khoản nợ mới. Khác [assign] ở chỗ không cần có sẵn giao
  /// dịch nào — dùng cho tiền đưa tay hoặc khoản ngân hàng không bắn thông báo.
  Future<void> record(Txn txn) async {
    await _dao.insert(txn);
    _changes.markChanged();
  }

  /// Ghi một giao dịch vào sổ nợ. Khoản nợ luôn được coi là đã xác nhận nên
  /// bỏ luôn cờ "cần xem lại" và cờ "không tính".
  Future<void> assign(
    Txn txn, {
    required DebtType type,
    required String person,
  }) async {
    await _dao.update(
      txn.copyWith(
        debtType: type,
        person: person.trim(),
        needsReview: false,
        excluded: false,
      ),
    );
    _changes.markChanged();
  }

  /// Gỡ giao dịch khỏi sổ nợ, đưa nó về lại Thu–Chi.
  Future<void> release(Txn txn) async {
    await _dao.update(txn.copyWith(clearDebt: true));
    _changes.markChanged();
  }
}
