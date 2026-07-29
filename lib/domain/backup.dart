import 'dart:convert';

import 'package:intl/intl.dart';

import '../models/models.dart';

/// Cách gộp dữ liệu trong file sao lưu với dữ liệu đang có trên máy.
enum RestoreMode {
  /// Giữ nguyên mọi thứ đang có, chỉ thêm những gì máy này chưa có. Giao dịch
  /// trùng được nhận ra qua khoá chống trùng nên nạp lại nhiều lần cũng không
  /// sinh ra bản sao.
  merge,

  /// Xoá sạch rồi nạp lại — đưa máy về đúng trạng thái lúc sao lưu.
  replace,
}

extension RestoreModeX on RestoreMode {
  String get label =>
      this == RestoreMode.merge ? 'Gộp thêm' : 'Thay thế toàn bộ';

  String get hint => this == RestoreMode.merge
      ? 'Giữ dữ liệu đang có, chỉ thêm phần còn thiếu'
      : 'Xoá hết dữ liệu trên máy rồi nạp lại từ file';
}

/// File sao lưu hỏng, sai định dạng, hoặc do app khác tạo ra.
class BackupError implements Exception {
  const BackupError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Nội dung một file sao lưu.
///
/// Sao lưu là bản chụp thẳng các bảng, không phải bản dịch sang một cấu trúc
/// riêng: thêm cột mới vào bảng thì bản sao lưu tự có cột đó, không phải nhớ
/// sửa thêm ở đây. Đổi lại, [schema] phải được kiểm khi nạp — file của bản app
/// mới hơn có thể mang cột mà bản đang chạy chưa biết.
class BackupData {
  const BackupData({
    required this.format,
    required this.schema,
    required this.createdAt,
    required this.tables,
  });

  /// Đời của chính định dạng file này. Tăng lên khi cấu trúc bọc ngoài đổi.
  static const int currentFormat = 1;

  /// Nhãn nhận dạng, để không nạp nhầm file JSON của app khác.
  static const String appTag = 'ting_ting';

  final int format;

  /// Đời schema database lúc sao lưu.
  final int schema;

  final DateTime createdAt;

  /// Tên bảng -> các dòng, mỗi dòng là map cột sang giá trị.
  final Map<String, List<Map<String, Object?>>> tables;

  int get rowCount => tables.values.fold(0, (sum, rows) => sum + rows.length);

  int countOf(String table) => tables[table]?.length ?? 0;

  String encode() => jsonEncode({
    'app': appTag,
    'format': format,
    'schema': schema,
    'created_at': createdAt.toIso8601String(),
    'tables': tables,
  });

  /// Đọc file sao lưu. Ném [BackupError] kèm câu giải thích cho user khi file
  /// không dùng được — mọi lý do đều phải nói rõ thay vì để app im lặng nạp ra
  /// một sổ rỗng.
  static BackupData decode(String raw, {required int supportedSchema}) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      throw const BackupError('File này không phải JSON hợp lệ.');
    }
    if (parsed is! Map<String, Object?>) {
      throw const BackupError('File này không phải bản sao lưu.');
    }
    if (parsed['app'] != appTag) {
      throw const BackupError('File này do app khác tạo ra, không nạp được.');
    }

    final format = _asInt(parsed['format']);
    if (format == null || format > currentFormat) {
      throw const BackupError(
        'File được tạo bởi bản app mới hơn. Cập nhật app rồi thử lại.',
      );
    }

    final schema = _asInt(parsed['schema']) ?? 0;
    if (schema > supportedSchema) {
      throw const BackupError(
        'Dữ liệu trong file mới hơn bản app đang chạy. Cập nhật app rồi thử lại.',
      );
    }

    final rawTables = parsed['tables'];
    if (rawTables is! Map<String, Object?>) {
      throw const BackupError('File sao lưu thiếu phần dữ liệu.');
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in rawTables.entries) {
      final rows = entry.value;
      if (rows is! List) {
        throw BackupError('Bảng "${entry.key}" trong file bị hỏng.');
      }
      tables[entry.key] = [
        for (final row in rows)
          if (row is Map<String, Object?>)
            row
          else
            throw BackupError('Bảng "${entry.key}" trong file bị hỏng.'),
      ];
    }

    return BackupData(
      format: format,
      schema: schema,
      createdAt:
          DateTime.tryParse(parsed['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      tables: tables,
    );
  }

  static int? _asInt(Object? value) => value is int ? value : null;
}

/// Số dòng thật sự được thêm vào sau một lần nạp, tách theo bảng.
class RestoreReport {
  const RestoreReport({required this.mode, required this.added});

  final RestoreMode mode;
  final Map<String, int> added;

  int get total => added.values.fold(0, (sum, n) => sum + n);

  int of(String table) => added[table] ?? 0;
}

/// Dấu phẩy hay dấu chấm phẩy giữa hai cột.
///
/// Máy đặt tiếng Việt dùng dấu phẩy làm dấu thập phân, nên Excel ở đó coi dấu
/// chấm phẩy mới là dấu ngăn cột. Xuất bằng dấu phẩy thì mở lên cả bảng dồn
/// vào một cột duy nhất.
const String csvSeparator = ';';

/// Excel không tự đoán ra UTF-8 nếu thiếu ba byte mở đầu này; thiếu nó thì
/// tiếng Việt có dấu hiện thành ký tự rác.
const String csvBom = '﻿';

/// Ngày giờ trong file xuất có định dạng riêng, không mượn của màn hình: đổi
/// cách app hiển thị ngày thì không được làm đổi luôn file người ta đã xuất.
final DateFormat _csvDay = DateFormat('dd/MM/yyyy');
final DateFormat _csvTime = DateFormat('HH:mm');

const List<String> _csvHeader = [
  'Ngày',
  'Giờ',
  'Nguồn',
  'Ví',
  'Hướng',
  'Số tiền',
  'Số dư',
  'Nhóm',
  'Nội dung',
  'Ghi chú',
  'Loại nợ',
  'Người',
  'Không tính',
  'Chuyển ví',
  'Cần xem lại',
];

/// Bảng giao dịch dạng CSV, mới nhất trước.
///
/// Số tiền để trần không định dạng: thêm dấu chấm phân nhóm vào thì Excel đọc
/// ra chữ chứ không ra số, cộng trừ trong bảng tính là hỏng.
String txnsToCsv(Iterable<Txn> txns) {
  final buffer = StringBuffer(csvBom)
    ..writeln(_csvHeader.map(_csvField).join(csvSeparator));
  for (final txn in txns) {
    buffer.writeln(
      <String>[
        _csvDay.format(txn.postTime),
        _csvTime.format(txn.postTime),
        txn.bankName,
        txn.accountKind.label,
        txn.direction.label,
        txn.signedAmount.toString(),
        txn.balance?.toString() ?? '',
        txn.category,
        txn.description ?? '',
        txn.note ?? '',
        txn.debtType?.label ?? '',
        txn.person ?? '',
        _flag(txn.excluded),
        _flag(txn.isTransfer),
        _flag(txn.needsReview),
      ].map(_csvField).join(csvSeparator),
    );
  }
  return buffer.toString();
}

String _flag(bool value) => value ? 'x' : '';

/// Bọc ô trong ngoặc kép khi nội dung có ký tự làm gãy cấu trúc bảng. Nội dung
/// giao dịch của ngân hàng hay có dấu chấm phẩy và xuống dòng.
String _csvField(String value) {
  final needsQuote =
      value.contains(csvSeparator) ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  if (!needsQuote) return value;
  return '"${value.replaceAll('"', '""')}"';
}
