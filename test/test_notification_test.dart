import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/bank_parser.dart';
import 'package:ting_ting/models/models.dart';
import 'package:ting_ting/services/test_notification.dart';

/// The test notification is only worth anything if the parser treats it the way
/// it treats a real bank message. Reword the body without checking and the
/// button starts reporting "nhận được, nhưng không ra số tiền" on a phone where
/// nothing is actually wrong.
void main() {
  final parsed = BankParser.parse(
    TestNotification.title,
    TestNotification.bodyAt(DateTime(2026, 7, 29, 14, 30)),
  );

  test('the fake bank message parses as a transaction', () {
    expect(parsed, isNotNull);
  });

  test('its amount is read as a confident expense', () {
    expect(parsed!.amount, 55000);
    expect(parsed.direction, TxnDirection.expense);
    expect(parsed.directionConfident, isTrue);
  });

  test('its balance is read, and not mistaken for the amount', () {
    expect(parsed!.balance, 12345678);
  });

  test('its description comes from the ND field', () {
    expect(parsed!.description, 'Ting Ting kiem tra doc thong bao');
  });
}
