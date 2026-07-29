import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/core/money.dart';

void main() {
  group('parseAmountInput', () {
    test('ô trống là không lọc, không phải lọc số 0', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('   '), isNull);
    });

    test('số trần đọc nguyên như gõ', () {
      expect(parseAmountInput('500000'), 500000);
      expect(parseAmountInput('0'), 0);
    });

    test('không có đuôi thì chấm phẩy là dấu phân cách hàng nghìn', () {
      expect(parseAmountInput('1.234.567'), 1234567);
      expect(parseAmountInput('1,234,567'), 1234567);
    });

    test('đuôi k nhân nghìn, đuôi tr và m nhân triệu', () {
      expect(parseAmountInput('500k'), 500000);
      expect(parseAmountInput('1tr'), 1000000);
      expect(parseAmountInput('2m'), 2000000);
    });

    test('có đuôi thì chấm phẩy lại là dấu thập phân', () {
      expect(parseAmountInput('1,5tr'), 1500000);
      expect(parseAmountInput('1.5tr'), 1500000);
      expect(parseAmountInput('2,5k'), 2500);
    });

    test('không phân biệt hoa thường, cho phép cách trước đuôi', () {
      expect(parseAmountInput('500K'), 500000);
      expect(parseAmountInput('1 TR'), 1000000);
    });

    test('gõ ra thứ không đọc được thì coi như không lọc', () {
      expect(parseAmountInput('abc'), isNull);
      expect(parseAmountInput('12abc'), isNull);
      expect(parseAmountInput('1.2.3tr'), isNull);
      expect(parseAmountInput('k'), isNull);
    });
  });
}
