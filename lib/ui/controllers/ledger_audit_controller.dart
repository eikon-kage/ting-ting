import '../../domain/txn_factory.dart';
import '../../models/models.dart';
import 'base_controller.dart';

/// Màn "Kiểm sổ": soi chuỗi số dư từng ngân hàng để tìm giao dịch bị lọt.
class LedgerAuditController extends BaseController {
  LedgerAuditController({super.data});

  LedgerAudit _audit = LedgerAudit.empty;

  /// Chỗ hở đang được ghi khoản bù — chặn bấm hai lần thành hai khoản.
  final Set<String> _filling = <String>{};

  LedgerAudit get audit => _audit;

  bool isFilling(LedgerGap gap) => _filling.contains(_keyOf(gap));

  Future<void> init() async {
    watchData();
    await refresh();
  }

  @override
  Future<void> refresh() => load(() async {
    _audit = await data.reports.auditLedger();
  });

  /// Ghi một giao dịch bù đúng bằng phần chênh, để chuỗi số dư khớp trở lại.
  ///
  /// Không cần tự gọi [refresh]: repository gõ chuông `data.changes` sau khi
  /// ghi, và màn này đang nghe chuông đó nên tự đối soát lại.
  ///
  /// Trả về `false` khi chỗ hở này đang được ghi dở.
  Future<bool> fill(LedgerGap gap) async {
    final key = _keyOf(gap);
    if (!_filling.add(key)) return false;
    notify();
    try {
      await data.txns.add(
        TxnFactory.missing(
          bankName: gap.bankName,
          direction: gap.direction,
          amount: gap.amount,
          at: _placeIn(gap),
          note:
              'Phát hiện khi kiểm sổ: số dư báo ${gap.actual}, '
              'sổ tính ra ${gap.expected}.',
        ),
      );
    } finally {
      _filling.remove(key);
      notify();
    }
    return true;
  }

  /// Ghi bù mọi chỗ hở đáng tin trong một lượt.
  Future<void> fillAll() async {
    for (final gap in _audit.gaps) {
      await fill(gap);
    }
  }

  /// Không ai biết giao dịch bị lọt xảy ra đúng lúc nào, chỉ biết nó nằm giữa
  /// hai mốc. Đặt sát ngay trước giao dịch làm lộ ra chênh lệch: vẫn nằm trong
  /// khoảng đúng, và chắc chắn xếp sau mốc trước nó nên mắt xích khớp lại.
  static DateTime _placeIn(LedgerGap gap) => gap.to.isAfter(gap.from)
      ? gap.to.subtract(const Duration(milliseconds: 1))
      : gap.to;

  static String _keyOf(LedgerGap gap) =>
      '${gap.bankName}|${gap.before.id}|${gap.after.id}';
}
