import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/bank_parser.dart';
import 'package:ting_ting/models/models.dart';

/// Thông báo thật lấy từ máy: Viettel Money xuống dòng từng trường, MB Bank
/// nhồi hết vào một dòng ngăn bằng "|".
const _viettelMoney =
    'Số tiền giao dịch: -2.000VND\n'
    'Số dư: 5.864VND\n'
    'Thời gian: 15:50 28/07/2026\n'
    'Nội dung: GD chuyen tien 260728549166502 NGUYEN QUANG VINH chuyen tien '
    'tu ViettelMoney';

const _mbBank =
    'TK 03xxx619|GD: +2,000VND 28/07/26 15:50 |SD: 1,810,591VND|'
    'TU: 970422....2407|ND: NGUYEN QUANG VINH chuyen tien tu ViettelMoney';

void main() {
  group('parser mặc định với thông báo thật', () {
    test('Viettel Money nhiều dòng: đọc đủ tiền, số dư, nội dung', () {
      final result = BankParser.parse('Biến động số dư', _viettelMoney);

      expect(result!.amount, 2000);
      expect(result.direction, TxnDirection.expense);
      expect(result.balance, 5864);
      expect(result.description, startsWith('GD chuyen tien 260728549166502'));
    });

    test('MB Bank một dòng ngăn bằng |', () {
      final result = BankParser.parse('Thông báo biến động số dư', _mbBank);

      expect(result!.amount, 2000);
      expect(result.direction, TxnDirection.income);
      expect(result.balance, 1810591);
      expect(result.description, 'NGUYEN QUANG VINH chuyen tien tu ViettelMoney');
    });

    test('nhãn nội dung không nằm cuối thông báo vẫn đọc được', () {
      final result = BankParser.parse(
        'Ngân hàng X',
        'GD: -50.000VND\nND: An trua\nThoi gian: 12:00 28/07/2026',
      );

      expect(result!.description, 'An trua');
    });
  });

  group('mẫu riêng của user', () {
    test('nhãn user khai đè lên cách dò mặc định', () {
      // Thông báo cố tình để số tài khoản có đuôi "d" đứng trước số tiền.
      const content =
          'Ghi no: Phi thuong nien 199000d\nGiao dich: 250.000 VND';
      final profile = ParserProfile(
        packageName: 'com.demo',
        amountLabel: 'Giao dich',
      );

      expect(BankParser.parse('Bank', content)!.amount, 199000);
      expect(
        BankParser.parse('Bank', content, profile: profile)!.amount,
        250000,
      );
    });

    test('nhãn khớp lỏng khoảng trắng và không phân biệt hoa thường', () {
      final profile = ParserProfile(
        packageName: 'com.demo',
        amountLabel: 'so tien   giao dich',
        balanceLabel: 'So Du',
      );
      final result = BankParser.parse(
        'Ví X',
        'THANH TOAN\nSO TIEN GIAO DICH: 12.000 VND\nSO DU: 88.000 VND',
        profile: profile,
      );

      expect(result!.amount, 12000);
      expect(result.balance, 88000);
    });

    test('regex tự viết được ưu tiên hơn nhãn', () {
      final profile = ParserProfile(
        packageName: 'com.demo',
        amountLabel: 'Số tiền',
        amountPattern: r'thay đổi (?<num>[\d.]+)',
      );
      final result = BankParser.parse(
        'Bank',
        'Ghi no. Số tiền: 1.000VND — thay đổi 777.000 VND',
        profile: profile,
      );

      expect(result!.amount, 777000);
    });

    test('regex hỏng thì quay về cách mặc định, không làm gãy luồng', () {
      final profile = ParserProfile(
        packageName: 'com.demo',
        amountPattern: r'(?<num>[\d',
      );

      expect(BankParser.isValidPattern(r'(?<num>[\d'), isFalse);
      expect(
        BankParser.parse('Bank', 'GD: -30.000VND', profile: profile)!.amount,
        30000,
      );
    });

    test('ép cứng hướng tiền cho app chỉ báo một chiều', () {
      final profile = ParserProfile(
        packageName: 'com.demo',
        directionMode: DirectionMode.alwaysIncome,
      );
      final result = BankParser.parse(
        'Ví',
        'Thanh toan thanh cong 20.000d',
        profile: profile,
      );

      expect(result!.direction, TxnDirection.income);
      expect(result.directionConfident, isTrue);
    });

    test('từ khoá user khai được cộng vào bộ mặc định', () {
      final profile = ParserProfile(
        packageName: 'com.demo',
        incomeHints: const ['nhan thanh toan'],
      );
      final result = BankParser.parse(
        'Ví',
        'Ban vua nhan thanh toan 15.000d',
        profile: profile,
      );

      expect(result!.direction, TxnDirection.income);
      expect(result.directionConfident, isTrue);
    });

    test('bỏ qua thông báo quảng cáo theo bộ lọc', () {
      final profile = ParserProfile(
        packageName: 'com.demo',
        ignoreIf: const ['khuyến mãi'],
      );

      expect(
        BankParser.parse(
          'Ưu đãi',
          'Nạp thẻ khuyến mãi tới 50.000đ hôm nay',
          profile: profile,
        ),
        isNull,
      );
    });

    test('chỉ nhận thông báo có từ khoá bắt buộc', () {
      final profile = ParserProfile(
        packageName: 'com.demo',
        onlyIf: const ['biến động số dư'],
      );

      expect(
        BankParser.parse('Quảng cáo', 'Vay ngay 10.000.000đ', profile: profile),
        isNull,
      );
      expect(
        BankParser.parse(
          'Biến động số dư',
          'GD: -10.000VND',
          profile: profile,
        ),
        isNotNull,
      );
    });

    test('mẫu rỗng cho kết quả y hệt khi không khai gì', () {
      final blank = ParserProfile(packageName: 'com.demo');

      expect(blank.isDefault, isTrue);
      expect(
        BankParser.parse('Bank', _mbBank, profile: blank)!.amount,
        BankParser.parse('Bank', _mbBank)!.amount,
      );
    });
  });
}
