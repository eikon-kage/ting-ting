import '../models/saved_qr.dart';

/// Số mã QR được nhớ. Quá số này thì cái cũ nhất rơi ra.
///
/// Người ta thu tiền quanh đi quẩn lại vài tài khoản và vài khoản cố định; danh
/// sách dài hơn một màn hình thì tìm trong đó còn lâu hơn gõ lại.
const int qrHistoryLimit = 20;

/// Đưa [entry] lên đầu danh sách đã nhớ.
///
/// Tạo lại đúng một mã cũ thì nó nhảy lên đầu chứ không nằm hai dòng giống hệt
/// nhau — và bản mới đè lên bản cũ, nên sửa tên chủ tài khoản rồi tạo lại là
/// tên mới được giữ.
List<SavedQr> withQrRemembered(List<SavedQr> history, SavedQr entry) {
  final kept = [
    entry,
    for (final saved in history)
      if (saved.identity != entry.identity) saved,
  ];
  return kept.length <= qrHistoryLimit ? kept : kept.sublist(0, qrHistoryLimit);
}

/// Bỏ [entry] khỏi danh sách đã nhớ.
List<SavedQr> withQrForgotten(List<SavedQr> history, SavedQr entry) => [
  for (final saved in history)
    if (saved.identity != entry.identity) saved,
];

/// Mã đang tạo đã nằm trong danh sách chưa.
bool isQrRemembered(List<SavedQr> history, SavedQr entry) =>
    history.any((saved) => saved.identity == entry.identity);
