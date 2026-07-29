import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ting_ting/domain/backup.dart';
import 'package:ting_ting/models/models.dart';

BackupData sample({int format = BackupData.currentFormat, int schema = 3}) =>
    BackupData(
      format: format,
      schema: schema,
      createdAt: DateTime(2026, 7, 29, 15, 30),
      tables: {
        'txns': [
          {'id': 1, 'amount': 150000, 'note': null},
        ],
        'rules': [
          {'id': 1, 'keyword': 'grab', 'category': 'Đi lại'},
        ],
      },
    );

Txn txn({
  int amount = 150000,
  bool income = false,
  int? balance,
  String? description,
  String? note,
  String category = 'Ăn uống',
  DebtType? debtType,
  String? person,
  bool excluded = false,
  AccountKind kind = AccountKind.bank,
}) => Txn(
  packageName: 'com.vcb',
  bankName: 'VCB',
  direction: income ? TxnDirection.income : TxnDirection.expense,
  amount: amount,
  balance: balance,
  description: description,
  note: note,
  category: category,
  rawTitle: '',
  rawContent: '',
  postTime: DateTime(2026, 7, 29, 14, 5),
  debtType: debtType,
  person: person,
  excluded: excluded,
  accountKind: kind,
);

/// Dòng thứ [index] của bảng CSV, bỏ qua dòng tiêu đề.
List<String> csvRow(String csv, int index) => csv
    .trim()
    .split('\n')[index + 1]
    .trim()
    .split(csvSeparator);

void main() {
  group('File sao lưu', () {
    test('ghi ra rồi đọc lại được nguyên vẹn', () {
      final decoded = BackupData.decode(
        sample().encode(),
        supportedSchema: 3,
      );

      expect(decoded.format, BackupData.currentFormat);
      expect(decoded.schema, 3);
      expect(decoded.createdAt, DateTime(2026, 7, 29, 15, 30));
      expect(decoded.countOf('txns'), 1);
      expect(decoded.tables['txns']!.single['amount'], 150000);
      expect(decoded.rowCount, 2);
    });

    test('giữ nguyên cả cột mà bản app này chưa biết đọc', () {
      final raw = jsonEncode({
        'app': 'ting_ting',
        'format': 1,
        'schema': 3,
        'created_at': '2026-07-29T15:30:00.000',
        'tables': {
          'txns': [
            {'id': 1, 'cot_moi_toanh': 'giữ lại'},
          ],
        },
      });

      final decoded = BackupData.decode(raw, supportedSchema: 3);
      expect(decoded.tables['txns']!.single['cot_moi_toanh'], 'giữ lại');
    });

    test('không nạp file không phải JSON', () {
      expect(
        () => BackupData.decode('đây không phải json', supportedSchema: 3),
        throwsA(isA<BackupError>()),
      );
    });

    test('không nạp file của app khác', () {
      final raw = jsonEncode({'app': 'app_khac', 'format': 1, 'tables': {}});
      expect(
        () => BackupData.decode(raw, supportedSchema: 3),
        throwsA(isA<BackupError>()),
      );
    });

    test('không nạp file do bản app mới hơn tạo ra', () {
      expect(
        () => BackupData.decode(
          sample(format: BackupData.currentFormat + 1).encode(),
          supportedSchema: 3,
        ),
        throwsA(isA<BackupError>()),
      );
    });

    test('không nạp file có schema mới hơn bản đang chạy', () {
      expect(
        () => BackupData.decode(sample(schema: 9).encode(), supportedSchema: 3),
        throwsA(isA<BackupError>()),
      );
    });

    test('báo lỗi khi phần dữ liệu bị hỏng', () {
      final raw = jsonEncode({
        'app': 'ting_ting',
        'format': 1,
        'schema': 3,
        'tables': {'txns': 'không phải danh sách'},
      });
      expect(
        () => BackupData.decode(raw, supportedSchema: 3),
        throwsA(isA<BackupError>()),
      );
    });
  });

  group('Xuất CSV', () {
    test('mở đầu bằng BOM để Excel đọc đúng tiếng Việt', () {
      expect(txnsToCsv([txn()]).startsWith(csvBom), isTrue);
    });

    test('có dòng tiêu đề và một dòng cho mỗi giao dịch', () {
      final lines = txnsToCsv([txn(), txn()]).trim().split('\n');
      expect(lines.length, 3);
      expect(lines.first, contains('Số tiền'));
    });

    test('số tiền để trần và mang dấu, để bảng tính cộng trừ được', () {
      expect(csvRow(txnsToCsv([txn(amount: 150000)]), 0)[5], '-150000');
      expect(
        csvRow(txnsToCsv([txn(amount: 150000, income: true)]), 0)[5],
        '150000',
      );
    });

    test('ô có dấu ngăn cột thì được bọc trong ngoặc kép', () {
      final row = txnsToCsv([
        txn(description: 'Mua đồ; trả sau'),
      ]).trim().split('\n')[1];
      expect(row, contains('"Mua đồ; trả sau"'));
    });

    test('dấu ngoặc kép trong nội dung được nhân đôi theo đúng chuẩn CSV', () {
      final row = txnsToCsv([
        txn(description: 'Quán "Ngon"'),
      ]).trim().split('\n')[1];
      expect(row, contains('"Quán ""Ngon"""'));
    });

    test('ô trống khi giao dịch không có số dư hay ghi chú', () {
      final row = csvRow(txnsToCsv([txn()]), 0);
      expect(row[6], '');
      expect(row[9], '');
    });

    test('khoản nợ và khoản không tính được đánh dấu rõ', () {
      final row = csvRow(
        txnsToCsv([
          txn(debtType: DebtType.lend, person: 'Bố', excluded: true),
        ]),
        0,
      );
      expect(row[10], 'Cho vay');
      expect(row[11], 'Bố');
      expect(row[12], 'x');
    });

    test('không có giao dịch nào thì vẫn ra bảng có tiêu đề', () {
      final csv = txnsToCsv(const <Txn>[]);
      expect(csv.trim().split('\n').length, 1);
      expect(csv, contains('Ngày'));
    });
  });
}
