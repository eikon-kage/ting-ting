import '../core/text.dart';
import '../models/models.dart';
import 'bill_split.dart';

/// An incoming payment that looks like someone settling what they owe.
///
/// It is only ever a guess put to the user as a question. Nothing is written
/// until they confirm it, because a friend sending the same amount for another
/// reason is perfectly ordinary.
sealed class RepaymentMatch {
  const RepaymentMatch({required this.person, required this.amount});

  /// The name as it is stored in the debt book or the bill.
  final String person;

  final int amount;

  /// The question shown on the notification and in the transaction sheet.
  String get question;
}

/// [person] is paying back the whole of what they owe in the debt book.
class DebtRepaymentMatch extends RepaymentMatch {
  const DebtRepaymentMatch({required super.person, required super.amount});

  @override
  String get question => 'Đánh dấu $person đã trả nợ?';
}

/// [person] is paying back their share of [bill].
class BillRepaymentMatch extends RepaymentMatch {
  const BillRepaymentMatch({
    required this.bill,
    required super.person,
    required super.amount,
  });

  final Bill bill;

  @override
  String get question => 'Đánh dấu $person đã trả phần bill "${bill.title}"?';
}

/// Whether [person] is named in [text], word for word.
///
/// Banks write the sender in capitals without diacritics ("NGUYEN VAN NAM"),
/// so both sides are flattened first. Whole words only, in order: "Nam" must
/// not be found inside "NAMA", and "Văn Nam" must not match "NAM VAN".
bool namesPerson(String text, String person) {
  final wanted = _words(person);
  if (wanted.isEmpty) return false;
  final words = _words(text);
  for (var i = 0; i + wanted.length <= words.length; i++) {
    var all = true;
    for (var j = 0; j < wanted.length; j++) {
      if (words[i + j] != wanted[j]) {
        all = false;
        break;
      }
    }
    if (all) return true;
  }
  return false;
}

List<String> _words(String input) => flatten(
  input,
).split(RegExp(r'[^a-z0-9]+')).where((word) => word.isNotEmpty).toList();

/// Looks for a debt or an open bill that [txn] would settle exactly.
///
/// Both the amount and the name have to match. The amount alone says nothing
/// (round sums are everywhere) and the name alone does not mean it is a
/// repayment. When the money could belong to more than one person the answer
/// is `null`: asking about the wrong person is worse than not asking.
///
/// A debt wins over a bill for the same person, since it is the older promise.
/// Among bills, the oldest one is settled first.
RepaymentMatch? matchRepayment(
  Txn txn, {
  required List<DebtSummary> debts,
  required List<BillOverview> bills,
}) {
  if (txn.direction != TxnDirection.income) return null;
  if (txn.isDebt || txn.isTransfer || txn.excluded) return null;
  final text = [
    txn.description,
    txn.rawTitle,
    txn.rawContent,
  ].whereType<String>().join(' ');

  final candidates = <RepaymentMatch>[];
  for (final debt in debts) {
    if (debt.balance != txn.amount) continue;
    if (!namesPerson(text, debt.person)) continue;
    candidates.add(DebtRepaymentMatch(person: debt.person, amount: txn.amount));
  }
  final open = [
    for (final entry in bills)
      if (!entry.bill.settled) entry,
  ]..sort((a, b) => a.bill.createdAt.compareTo(b.bill.createdAt));
  for (final entry in open) {
    for (final person in entry.bill.others) {
      if (entry.settlement.owedToMeBy(person) != txn.amount) continue;
      if (!namesPerson(text, person)) continue;
      candidates.add(
        BillRepaymentMatch(
          bill: entry.bill,
          person: person,
          amount: txn.amount,
        ),
      );
    }
  }

  if (candidates.isEmpty) return null;
  final people = {for (final c in candidates) c.person.toLowerCase()};
  if (people.length > 1) return null;
  return candidates.first;
}
