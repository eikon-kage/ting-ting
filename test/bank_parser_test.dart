import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/core/text.dart';
import 'package:ting_ting/domain/bank_parser.dart';
import 'package:ting_ting/domain/categorizer.dart';
import 'package:ting_ting/models/models.dart';

void main() {
  group('BankParser', () {
    test('đọc được giao dịch trừ tiền có dấu âm và số dư', () {
      final result = BankParser.parse(
        'Biến động số dư',
        'TK 0123456789|GD:-150,000VND 28/07/26 14:30|SD:2,345,678VND|ND: '
            'Thanh toan Highlands Coffee',
      );

      expect(result, isNotNull);
      expect(result!.amount, 150000);
      expect(result.direction, TxnDirection.expense);
      expect(result.directionConfident, isTrue);
      expect(result.balance, 2345678);
      expect(result.description, 'Thanh toan Highlands Coffee');
    });

    test('đọc được tiền vào và không nhầm số dư thành số tiền', () {
      final result = BankParser.parse(
        'MB Bank',
        'TK 9704|GD: +5.000.000VND luc 28/07/2026|SD: 12.345.678VND|'
            'ND: ME CHUYEN TIEN',
      );

      expect(result!.amount, 5000000);
      expect(result.direction, TxnDirection.income);
      expect(result.balance, 12345678);
      expect(result.description, 'ME CHUYEN TIEN');
    });

    test('dựa vào từ khoá khi thông báo không có dấu +/-', () {
      final result = BankParser.parse(
        'MoMo',
        'Bạn đã thanh toán 45.000đ cho Grab',
      );

      expect(result!.amount, 45000);
      expect(result.direction, TxnDirection.expense);
      expect(result.directionConfident, isTrue);
    });

    test('nhận dạng ghi có là tiền vào kể cả khi viết không dấu', () {
      final result = BankParser.parse(
        'Techcombank',
        'Tai khoan 1903 duoc ghi co 2,000,000 VND',
      );

      expect(result!.direction, TxnDirection.income);
      expect(result.amount, 2000000);
    });

    test('hiểu ký hiệu (+) (-) kiểu ACB', () {
      final result = BankParser.parse('ACB', 'TK 123 (+)500,000VND');

      expect(result!.direction, TxnDirection.income);
      expect(result.amount, 500000);
    });

    test('bỏ qua số tiền không kèm dấu +/- lẫn từ khoá hướng tiền', () {
      // An amount alone says nothing about money moving. Guessing "expense" and
      // flagging it for review turned every promo and receipt-shaped message
      // into a transaction the user had to go and delete.
      expect(BankParser.parse('Ngân hàng X', 'Giao dich 100.000 VND'), isNull);
      expect(BankParser.parse('Shop', 'Giảm giá 50.000đ cho đơn sau'), isNull);
    });

    test('vẫn ghi nhận khi từ khoá hai phía cùng khớp, chỉ cắm cờ hỏi lại', () {
      // Conflicting evidence is still evidence: money moved, the direction is
      // what's unclear. Only the no-evidence-at-all case gets dropped.
      final result = BankParser.parse(
        'Ngân hàng X',
        'Ghi co tien thanh toan 100.000 VND',
      );

      expect(result, isNotNull);
      expect(result!.amount, 100000);
      expect(result.directionConfident, isFalse);
    });

    test('mẫu bóc tách khai sẵn hướng tiền thì không cần dấu +/-', () {
      final result = BankParser.parse(
        'Ngân hàng X',
        'Giao dich 100.000 VND',
        profile: const ParserProfile(
          packageName: 'com.bank.x',
          directionMode: DirectionMode.alwaysExpense,
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 100000);
      expect(result.direction, TxnDirection.expense);
      expect(result.directionConfident, isTrue);
    });

    test('bỏ qua thông báo không có tiền', () {
      expect(BankParser.parse('Zalo', 'Bạn có tin nhắn mới'), isNull);
      expect(BankParser.parse('', ''), isNull);
    });

    test('không nhầm số điện thoại hay mã giao dịch thành số tiền', () {
      expect(
        BankParser.parse('OTP', 'Ma xac thuc cua ban la 483920'),
        isNull,
      );
    });

    test('không đọc "đ" đứng đầu từ tiếng Việt thành đơn vị tiền', () {
      // The unit is one bare "đ", so "đơn", "đường", "đồ" used to end an amount
      // match and the number in front of them became a transaction.
      expect(BankParser.parse('Shopee', 'Bạn có 3 đơn hàng mới'), isNull);
      expect(BankParser.parse('Grab', 'Tài xế đã đến 2 đường Nguyễn Trãi'), isNull);
      expect(BankParser.parse('Shop', 'Còn 5 đồ chưa lấy'), isNull);
    });
  });

  group('Categorizer', () {
    test('gán nhóm theo từ khoá mặc định', () {
      expect(
        Categorizer.categorize('Thanh toan GRAB', TxnDirection.expense).category,
        'Đi lại',
      );
      expect(
        Categorizer.categorize('bat ky', TxnDirection.income).category,
        'Thu nhập',
      );
    });

    test('quy tắc của user được ưu tiên hơn từ khoá mặc định', () {
      final suggestion = Categorizer.categorize(
        'Thanh toan GRAB cho me',
        TxnDirection.expense,
        userRules: [
          Rule(keyword: 'cho mẹ', category: 'Gia đình', autoExclude: true),
        ],
      );

      expect(suggestion.category, 'Gia đình');
      expect(suggestion.excluded, isTrue);
    });
  });

  group('removeDiacritics', () {
    test('bỏ dấu tiếng Việt', () {
      expect(removeDiacritics('Số dư đã thay đổi'), 'So du da thay doi');
    });
  });
}
