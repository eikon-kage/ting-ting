import '../../domain/txn_factory.dart';
import '../../domain/txn_grouping.dart';
import '../../models/models.dart';
import 'base_controller.dart';

/// Sổ nợ: ai đang nợ mình, mình đang nợ ai.
class DebtController extends BaseController {
  DebtController({super.data});

  DebtOverview _overview = DebtOverview.empty;

  DebtOverview get overview => _overview;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _overview = await data.debts.overview();
  });
}

/// Lịch sử vay/trả với một người.
class PersonDebtController extends BaseController {
  PersonDebtController({required this.person, super.data});

  final String person;

  List<Txn> _txns = const [];
  int _balance = 0;

  List<Txn> get txns => _txns;

  /// Dương = họ đang nợ mình.
  int get balance => _balance;

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _txns = await data.debts.historyFor(person);
    _balance = debtBalanceOf(_txns);
  });
}

/// Ghi thẳng một khoản nợ mới, không đi từ giao dịch nào có sẵn.
class AddDebtController extends BaseController {
  AddDebtController({DebtType? initialType, super.data})
    : _type = initialType ?? DebtType.lend;

  DebtType _type;
  AccountKind _accountKind = AccountKind.cash;
  DateTime _when = DateTime.now();
  List<String> _suggestions = const [];
  bool _saving = false;

  DebtType get type => _type;
  AccountKind get accountKind => _accountKind;
  DateTime get when => _when;

  /// Tên người đã từng dùng, để bấm chọn thay vì gõ lại.
  List<String> get suggestions => _suggestions;

  bool get saving => _saving;

  /// Tiền ra khỏi ví hay vào ví — suy từ loại nợ đang chọn.
  bool get isOutgoing => _type.direction == TxnDirection.expense;

  Future<void> init() => refresh();

  @override
  Future<void> refresh() => load(() async {
    _suggestions = await data.debts.knownPeople();
  });

  void selectType(DebtType value) {
    _type = value;
    notify();
  }

  void selectAccountKind(AccountKind value) {
    _accountKind = value;
    notify();
  }

  void selectWhen(DateTime value) {
    _when = value;
    notify();
  }

  /// Trả về `false` nếu đang lưu dở — bấm hai lần không thành hai khoản nợ.
  Future<bool> save({
    required int amount,
    required String person,
    required String walletName,
    String? note,
  }) async {
    if (_saving) return false;
    _saving = true;
    notify();
    await data.debts.record(
      TxnFactory.debt(
        type: _type,
        amount: amount,
        person: person,
        postTime: _when,
        accountKind: _accountKind,
        walletName: walletName,
        note: note,
      ),
    );
    _saving = false;
    notify();
    return true;
  }
}

/// Sheet gán một giao dịch vào sổ nợ.
class AssignDebtController extends BaseController {
  AssignDebtController({required this.txn, super.data})
    : _type =
          txn.debtType ??
          (txn.direction == TxnDirection.income
              ? DebtType.collect
              : DebtType.lend);

  final Txn txn;

  DebtType _type;
  List<String> _suggestions = const [];

  DebtType get type => _type;
  List<String> get suggestions => _suggestions;

  /// Loại nợ khả dĩ tuỳ theo tiền vào hay tiền ra.
  List<DebtType> get options => txn.direction == TxnDirection.income
      ? const [DebtType.collect, DebtType.borrow]
      : const [DebtType.lend, DebtType.repay];

  Future<void> init() => refresh();

  @override
  Future<void> refresh() => load(() async {
    _suggestions = await data.debts.knownPeople();
  });

  void selectType(DebtType type) {
    _type = type;
    notify();
  }

  /// Trả về `false` nếu chưa nhập tên người — sheet giữ nguyên để user nhập.
  Future<bool> save(String person) async {
    if (person.trim().isEmpty) return false;
    await data.debts.assign(txn, type: _type, person: person);
    return true;
  }

  Future<void> release() => data.debts.release(txn);
}
