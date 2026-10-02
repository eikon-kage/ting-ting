import 'dart:convert';

/// Một mã QR user đã tạo, giữ lại để lần sau chỉ mất một cú chạm thay vì gõ lại
/// mười hai chữ số.
///
/// Cất dưới dạng JSON trong bảng cài đặt chứ không dựng bảng riêng: danh sách
/// này ngắn, chỉ màn QR đọc tới, mà đi qua bảng cài đặt thì bản sao lưu tự mang
/// theo và schema không phải lên đời.
class SavedQr {
  const SavedQr({
    required this.bankBin,
    required this.accountNumber,
    this.holderName = '',
    this.amount,
    this.note = '',
  });

  /// Đọc lại một mã. Trả `null` với thứ không đọc được — chỗ điền sẵn hỏng
  /// không đáng làm sập màn hình.
  static SavedQr? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final bin = raw['bankBin'];
    final account = raw['accountNumber'];
    if (bin is! String || account is! String) return null;
    final amount = raw['amount'];
    return SavedQr(
      bankBin: bin,
      accountNumber: account,
      holderName: raw['holderName'] is String
          ? raw['holderName'] as String
          : '',
      amount: amount is int && amount > 0 ? amount : null,
      note: raw['note'] is String ? raw['note'] as String : '',
    );
  }

  /// Đọc cả danh sách, bỏ qua dòng hỏng thay vì vứt luôn những dòng còn lành.
  static List<SavedQr> decodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      // Bản trước chỉ nhớ được một tài khoản và ghi thẳng một object.
      if (decoded is Map) {
        final single = fromJson(decoded);
        return single == null ? const [] : [single];
      }
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?fromJson(item)];
    } on FormatException {
      return const [];
    }
  }

  static String encodeList(List<SavedQr> entries) =>
      jsonEncode([for (final entry in entries) entry._toJson()]);

  /// NAPAS BIN của ngân hàng, không phải tên — tên đổi, BIN thì không.
  final String bankBin;

  final String accountNumber;

  /// Chỉ in lên ảnh. Mã QR không mang theo tên này.
  final String holderName;

  /// Số tiền điền sẵn. `null` nghĩa là mã dùng lại được nhiều lần.
  final int? amount;

  final String note;

  /// Hai mã là một khi cùng ngân hàng, tài khoản, số tiền và nội dung. Tên chủ
  /// tài khoản không tính: sửa lại cách viết hoa không đẻ ra một mã khác.
  String get identity => '$bankBin|$accountNumber|${amount ?? ''}|$note';

  Map<String, Object?> _toJson() => {
    'bankBin': bankBin,
    'accountNumber': accountNumber,
    'holderName': holderName,
    if (amount != null) 'amount': amount,
    'note': note,
  };
}
