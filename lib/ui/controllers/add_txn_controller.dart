import '../../domain/categorizer.dart';
import '../../domain/txn_factory.dart';
import '../../models/models.dart';
import 'base_controller.dart';

/// Nhập giao dịch bằng tay — cho tiền mặt hoặc khoản mà notification bỏ sót.
class AddTxnController extends BaseController {
  AddTxnController({super.data});

  TxnDirection _direction = TxnDirection.expense;
  AccountKind _accountKind = AccountKind.cash;
  String _category = Categorizer.uncategorized;
  DateTime _when = DateTime.now();
  bool _saving = false;

  TxnDirection get direction => _direction;
  AccountKind get accountKind => _accountKind;
  String get category => _category;
  DateTime get when => _when;
  bool get saving => _saving;

  /// Màn này không tải gì, chỉ nhập.
  @override
  Future<void> refresh() async {}

  /// Đổi thu/chi thì gợi ý lại nhóm cho khớp.
  void selectDirection(TxnDirection value) {
    _direction = value;
    _category = value == TxnDirection.income
        ? Categorizer.income
        : Categorizer.uncategorized;
    notify();
  }

  void selectAccountKind(AccountKind value) {
    _accountKind = value;
    notify();
  }

  void selectCategory(String value) {
    _category = value;
    notify();
  }

  void selectWhen(DateTime value) {
    _when = value;
    notify();
  }

  /// Trả về `false` nếu đang lưu dở — tránh bấm hai lần thành hai giao dịch.
  Future<bool> save({
    required int amount,
    required String walletName,
    String? description,
    String? note,
  }) async {
    if (_saving) return false;
    _saving = true;
    notify();
    await data.txns.add(
      TxnFactory.manual(
        direction: _direction,
        amount: amount,
        category: _category,
        postTime: _when,
        accountKind: _accountKind,
        walletName: walletName,
        description: description,
        note: note,
      ),
    );
    _saving = false;
    notify();
    return true;
  }
}
