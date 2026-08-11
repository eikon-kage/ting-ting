import '../../domain/bill_split.dart';
import '../../models/models.dart';
import '../dao/bill_dao.dart';
import '../data_changes.dart';

/// Các cuộc chia tiền.
///
/// Không đụng gì tới bảng giao dịch: bill chỉ tính xem ai nợ ai, còn tiền thật
/// ra vào ví thì thông báo ngân hàng đã ghi rồi.
class BillRepository {
  BillRepository(this._dao, this._changes);

  final BillDao _dao;
  final DataChanges _changes;

  /// Mọi bill kèm số liệu đã chốt, mới nhất lên đầu.
  Future<List<BillOverview>> overview() async {
    final bills = await _dao.allBills();
    final items = await _dao.itemsByBill();
    return [
      for (final bill in bills)
        BillOverview(
          bill: bill,
          settlement: settleBill(bill, items[bill.key] ?? const []),
        ),
    ];
  }

  Future<Bill?> byKey(String key) => _dao.billByKey(key);

  Future<List<BillItem>> items(String billKey) => _dao.itemsOf(billKey);

  Future<void> save(Bill bill) async {
    await _dao.saveBill(bill);
    _changes.markChanged();
  }

  Future<void> remove(String billKey) async {
    await _dao.deleteBill(billKey);
    _changes.markChanged();
  }

  Future<void> saveItem(BillItem item) async {
    await _dao.saveItem(item);
    _changes.markChanged();
  }

  Future<void> removeItem(String itemKey) async {
    await _dao.deleteItem(itemKey);
    _changes.markChanged();
  }
}
