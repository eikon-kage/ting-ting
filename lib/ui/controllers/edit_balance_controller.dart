import '../../domain/txn_factory.dart';
import '../../models/models.dart';
import 'base_controller.dart';

/// Sửa "số tiền đang có" của một ví.
///
/// Không ghi đè số dư — nó là số dẫn xuất. Controller chỉ ghi một khoản chênh
/// lệch để tổng khớp với con số user vừa nhập, xem [TxnFactory.balanceAdjustment].
class EditBalanceController extends BaseController {
  EditBalanceController({
    super.data,
    required this.accountKind,
    required this.current,
  });

  final AccountKind accountKind;

  /// Số đang hiện trên màn chính, dùng để tính phần chênh lệch.
  final int current;

  bool _saving = false;

  bool get saving => _saving;

  /// Sheet này không tải gì, số dư hiện tại được truyền vào sẵn.
  @override
  Future<void> refresh() async {}

  int deltaTo(int target) => target - current;

  /// Trả về `false` khi đang lưu dở hoặc số dư không đổi.
  Future<bool> save({required int target, required String walletName}) async {
    if (_saving) return false;
    final adjustment = TxnFactory.balanceAdjustment(
      accountKind: accountKind,
      walletName: walletName,
      current: current,
      target: target,
      at: DateTime.now(),
    );
    if (adjustment == null) return false;
    _saving = true;
    notify();
    await data.txns.add(adjustment);
    _saving = false;
    notify();
    return true;
  }
}
