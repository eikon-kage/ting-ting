import '../../domain/repayment_match.dart';
import '../../models/models.dart';
import 'bill_repository.dart';
import 'debt_repository.dart';
import 'txn_repository.dart';

/// Ties incoming money to the debt or bill it pays off.
///
/// Both the notification button and the transaction sheet go through here, so
/// the check is always made against the debt book and bills as they are at
/// that moment. A notification can sit unanswered for days while the user
/// marks the same repayment some other way.
class RepaymentRepository {
  RepaymentRepository(this._txns, this._debts, this._bills);

  final TxnRepository _txns;
  final DebtRepository _debts;
  final BillRepository _bills;

  Future<RepaymentMatch?> matchFor(Txn txn) async {
    if (txn.direction != TxnDirection.income) return null;
    final debts = await _debts.overview();
    return matchRepayment(
      txn,
      debts: debts.people,
      bills: await _bills.overview(),
    );
  }

  /// Records [txn] as the repayment [match] describes.
  ///
  /// Returns `false` when the match no longer holds (already marked, or the
  /// debt changed since), in which case nothing is written.
  Future<bool> confirm(Txn txn, RepaymentMatch match) async {
    final current = await matchFor(txn);
    if (current == null || !_same(current, match)) return false;
    switch (current) {
      case DebtRepaymentMatch(:final person):
        await _debts.assign(txn, type: DebtType.collect, person: person);
      case BillRepaymentMatch(:final bill, :final person, :final amount):
        await _txns.save(
          txn.copyWith(category: Category.shareBill, needsReview: false),
        );
        final paid = bill.withRepayment(person, amount);
        final settlement = (await _bills.overview())
            .where((entry) => entry.bill.key == bill.key)
            .map((entry) => entry.settlement)
            .firstOrNull;
        // The last payback that brings the whole bill level closes it, the
        // same as the user ticking "done" by hand.
        final level =
            settlement != null &&
            settlement.transfers.length == 1 &&
            settlement.owedToMeBy(person) == amount;
        await _bills.save(level ? paid.copyWith(settled: true) : paid);
    }
    return true;
  }

  static bool _same(RepaymentMatch? a, RepaymentMatch b) => switch ((a, b)) {
    (DebtRepaymentMatch a, DebtRepaymentMatch b) =>
      a.person == b.person && a.amount == b.amount,
    (BillRepaymentMatch a, BillRepaymentMatch b) =>
      a.bill.key == b.bill.key && a.person == b.person && a.amount == b.amount,
    _ => false,
  };
}
