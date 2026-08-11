import '../../domain/bill_split.dart';
import '../../models/models.dart';
import 'base_controller.dart';

/// Danh sách các cuộc chia tiền.
class BillsController extends BaseController {
  BillsController({super.data});

  List<BillOverview> _bills = const [];
  List<String> _suggestions = const [];

  List<BillOverview> get bills => _bills;

  /// Tên đã dùng ở bill trước hoặc trong sổ nợ, để bấm chọn thay vì gõ lại.
  List<String> get suggestions => _suggestions;

  /// Còn phải đưa cho người khác bao nhiêu, cộng mọi bill chưa tất toán.
  int get owedByMe => _sumMyNet(negative: true);

  /// Còn được nhận về bao nhiêu.
  int get owedToMe => _sumMyNet(negative: false);

  int _sumMyNet({required bool negative}) {
    var total = 0;
    for (final entry in _bills) {
      if (entry.bill.settled) continue;
      final net = entry.settlement.myNet;
      if (negative && net < 0) total -= net;
      if (!negative && net > 0) total += net;
    }
    return total;
  }

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _bills = await data.bills.overview();
    _suggestions = await _knownNames();
  });

  /// Người từng đi cùng đứng trước, rồi tới tên đã có trong sổ nợ.
  Future<List<String>> _knownNames() async {
    final names = <String>[];
    for (final entry in _bills) {
      names.addAll(entry.bill.others);
    }
    return Bill.mergeMembers(const [], [
      ...names,
      ...await data.debts.knownPeople(),
    ]);
  }

  /// Trả về bill vừa tạo để màn hình mở thẳng vào nó.
  Future<Bill> create({
    required String title,
    required List<String> members,
  }) async {
    final bill = Bill.create(title: title, others: members);
    await data.bills.save(bill);
    return bill;
  }

  Future<void> remove(String billKey) => data.bills.remove(billKey);
}

/// Một cuộc chia tiền: các mục đã tiêu và bảng chốt sổ.
class BillController extends BaseController {
  BillController({required this.billKey, super.data});

  final String billKey;

  Bill? _bill;
  List<BillItem> _items = const [];
  BillSettlement _settlement = BillSettlement.empty;

  Bill? get bill => _bill;
  List<BillItem> get items => _items;
  BillSettlement get settlement => _settlement;

  List<String> get members => _bill?.members ?? const [];

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    final bill = await data.bills.byKey(billKey);
    _bill = bill;
    _items = bill == null ? const [] : await data.bills.items(billKey);
    _settlement = bill == null
        ? BillSettlement.empty
        : settleBill(bill, _items);
  });

  /// Người này đã trả hoặc đang gánh mục nào đó — gỡ khỏi bill thì con số của
  /// họ vẫn còn trong bảng chốt sổ, nên màn hình không cho gỡ.
  bool memberInUse(String person) => _items.any(
    (item) => item.payer == person || item.people.contains(person),
  );

  Future<void> saveItem(BillItem item) => data.bills.saveItem(item);

  Future<void> removeItem(String itemKey) => data.bills.removeItem(itemKey);

  Future<void> addMembers(Iterable<String> names) async {
    final bill = _bill;
    if (bill == null) return;
    final merged = Bill.mergeMembers(bill.members, names);
    if (merged.length == bill.members.length) return;
    await data.bills.save(bill.copyWith(members: merged));
  }

  Future<void> removeMember(String person) async {
    final bill = _bill;
    if (bill == null || person == Bill.me || memberInUse(person)) return;
    await data.bills.save(
      bill.copyWith(
        members: [
          for (final member in bill.members)
            if (member != person) member,
        ],
      ),
    );
  }

  Future<void> rename(String title) async {
    final bill = _bill;
    final name = title.trim();
    if (bill == null || name.isEmpty) return;
    await data.bills.save(bill.copyWith(title: name));
  }

  Future<void> toggleSettled() async {
    final bill = _bill;
    if (bill == null) return;
    await data.bills.save(bill.copyWith(settled: !bill.settled));
  }

  Future<void> remove() => data.bills.remove(billKey);
}
