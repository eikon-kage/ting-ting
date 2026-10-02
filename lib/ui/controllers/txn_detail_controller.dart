import 'dart:async';

import '../../domain/repayment_match.dart';
import '../../models/models.dart';
import 'base_controller.dart';

/// Bottom sheet chi tiết một giao dịch: sửa loại thu/chi, nhóm, ghi chú, nợ,
/// chuyển ví, xoá.
class TxnDetailController extends BaseController {
  TxnDetailController({required Txn txn, super.data}) : _txn = txn;

  /// Ghi chú lưu ngay khi gõ, nhưng gom lại để không ghi database mỗi phím.
  static const Duration _notePause = Duration(milliseconds: 400);

  Txn _txn;
  Timer? _noteDebounce;

  Txn get txn => _txn;

  RepaymentMatch? _repayment;

  /// Set when this money looks like someone paying the user back.
  RepaymentMatch? get repayment => _repayment;

  /// Checks whether the transaction pays off a debt or a bill share.
  Future<void> findRepayment() async {
    _repayment = await data.repayments.matchFor(_txn);
    notify();
  }

  /// Records the repayment the user just confirmed, then re-reads the
  /// transaction since it has moved to the debt book or the bill category.
  Future<void> confirmRepayment() async {
    final match = _repayment;
    if (match == null) return;
    _repayment = null;
    notify();
    await data.repayments.confirm(_txn, match);
    await refresh();
  }

  void dismissRepayment() {
    _repayment = null;
    notify();
  }

  /// Sheet nhận sẵn giao dịch nên không có gì phải tải lúc mở; hàm này chỉ
  /// dùng khi cần lấy lại bản mới nhất (ví dụ sau khi gán nợ).
  @override
  Future<void> refresh() async {
    final id = _txn.id;
    if (id == null) return;
    final latest = await data.txns.byId(id);
    if (latest == null) return;
    _txn = latest;
    notify();
  }

  @override
  void dispose() {
    _noteDebounce?.cancel();
    super.dispose();
  }

  /// Cập nhật ngay trên màn rồi mới ghi xuống, để công tắc không bị giật.
  Future<void> apply(Txn updated) async {
    _txn = updated;
    // Any manual change answers the question in its own way.
    _repayment = null;
    notify();
    await data.txns.save(updated);
  }

  void editNote(String note) {
    _txn = _txn.copyWith(note: note);
    _noteDebounce?.cancel();
    _noteDebounce = Timer(_notePause, () => data.txns.save(_txn));
  }

  Future<void> delete() async {
    final id = _txn.id;
    if (id == null) return;
    _noteDebounce?.cancel();
    await data.txns.remove(id);
  }
}
