import 'package:flutter/widgets.dart';

import '../../domain/vietqr.dart';
import '../../domain/vietqr_banks.dart';
import '../../models/models.dart';
import '../../services/qr_files.dart';
import 'base_controller.dart';

/// Kết quả một lần tải ảnh về, để màn hình biết báo gì cho user.
class QrOutcome {
  const QrOutcome.done(this.message) : failed = false;
  const QrOutcome.failed(this.message) : failed = true;

  /// User đóng hộp chia sẻ giữa chừng — không phải lỗi, không cần báo gì.
  static const QrOutcome? cancelled = null;

  final String message;
  final bool failed;
}

/// Màn "Mã QR nhận tiền": dựng chuỗi VietQR từ số tài khoản và xuất ảnh.
///
/// Mã được sinh ngay trên máy, không gọi ra dịch vụ nào — số tài khoản không
/// rời khỏi điện thoại cho tới lúc user tự chọn gửi ảnh đi.
class QrController extends BaseController {
  QrController({super.data, QrFiles? files})
    : files = files ?? QrFiles.instance;

  final QrFiles files;

  VietQrBank? _bank;
  String _accountNumber = '';
  String _holderName = '';
  String _note = '';
  int? _amount;
  String? _payload;
  String? _error;
  bool _busy = false;

  VietQrBank? get bank => _bank;
  String get accountNumber => _accountNumber;
  String get holderName => _holderName;
  String get note => _note;
  int? get amount => _amount;

  /// Chuỗi VietQR dựng từ những gì đang nhập, `null` khi còn thiếu hoặc sai.
  String? get payload => _payload;

  /// Câu giải thích vì sao chưa dựng được mã, `null` khi không có gì để nói.
  String? get error => _error;

  /// Đang xuất ảnh — khoá nút để không bấm chồng lên nhau.
  bool get busy => _busy;

  /// Đã đủ dữ liệu để hiện mã QR.
  bool get ready => _payload != null;

  Future<void> init() => refresh();

  /// Điền lại tài khoản của lần trước. Số tiền và nội dung thì không: chúng
  /// thuộc về một lần thu tiền cụ thể, lần sau gần như chắc chắn khác.
  @override
  Future<void> refresh() => load(() async {
    final saved = await data.settings.readQrAccount();
    if (saved == null) return;
    _bank = bankByBin(saved.bankBin);
    _accountNumber = saved.accountNumber;
    _holderName = saved.holderName;
    _rebuild();
  });

  void selectBank(VietQrBank bank) {
    _bank = bank;
    _rebuild();
    notify();
  }

  void accountChanged(String value) {
    _accountNumber = value;
    _rebuild();
    notify();
  }

  void holderChanged(String value) {
    _holderName = value;
    // Tên chủ tài khoản chỉ in lên ảnh, không nằm trong mã — không cần dựng lại
    // chuỗi, nhưng thẻ xem trước thì phải vẽ lại.
    notify();
  }

  void amountChanged(int? value) {
    _amount = value;
    _rebuild();
    notify();
  }

  void noteChanged(String value) {
    _note = value;
    _rebuild();
    notify();
  }

  /// Nội dung chuyển khoản sau khi bỏ dấu và cắt bớt — đúng chữ người gửi sẽ
  /// thấy trong app ngân hàng của họ.
  String get normalizedNote => normalizeQrNote(_note);

  /// Xuất thẻ mã QR đang hiện thành ảnh PNG rồi mở hộp chia sẻ.
  ///
  /// [cardKey] trỏ tới [RepaintBoundary] bọc thẻ; màn hình phải kéo nó vào tầm
  /// nhìn trước khi gọi, vẽ lại một widget đã cuộn khỏi màn thì không ra ảnh.
  Future<QrOutcome?> download(GlobalKey cardKey) async {
    if (_busy || _payload == null) return null;
    _busy = true;
    notify();
    try {
      // Ghi tài khoản lại trước khi chia sẻ: user đã tạo tới ảnh nghĩa là tài
      // khoản này đúng, kể cả khi họ đổi ý ở hộp chia sẻ.
      await _remember();
      final png = await files.renderPng(cardKey);
      if (png == null) {
        return const QrOutcome.failed('Không dựng được ảnh, thử lại lần nữa');
      }
      final shared = await files.shareQr(
        png,
        fileName: _fileName(),
        subject: 'Mã QR nhận tiền',
        text: _shareText(),
      );
      if (!shared) return QrOutcome.cancelled;
      return const QrOutcome.done('Đã xuất ảnh mã QR');
    } catch (e) {
      return QrOutcome.failed('Không xuất được ảnh: $e');
    } finally {
      _busy = false;
      notify();
    }
  }

  Future<void> _remember() async {
    final bank = _bank;
    if (bank == null) return;
    await data.settings.writeQrAccount(
      QrAccount(
        bankBin: bank.bin,
        accountNumber: _accountNumber.trim(),
        holderName: _holderName.trim(),
      ),
    );
  }

  /// Tên file có tên ngân hàng và bốn số cuối tài khoản — user tải nhiều mã về
  /// một thư mục vẫn phân biệt được, mà không in cả số tài khoản ra tên file.
  String _fileName() {
    final digits = _accountNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final tail = digits.length <= 4
        ? digits
        : digits.substring(digits.length - 4);
    final bank =
        _bank?.shortName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '') ?? 'qr';
    return 'tingting-qr-$bank-$tail.png';
  }

  String _shareText() {
    final parts = [
      if (_bank != null) _bank!.shortName,
      _accountNumber.trim(),
      if (_holderName.trim().isNotEmpty) _holderName.trim().toUpperCase(),
    ];
    return 'Quét mã để chuyển tiền · ${parts.join(' · ')}';
  }

  /// Dựng lại chuỗi sau mỗi lần user gõ. Ném ra lỗi thì giữ lại câu giải thích
  /// và bỏ mã đi — thà không có mã còn hơn có một mã không quét được.
  void _rebuild() {
    final bank = _bank;
    if (bank == null || _accountNumber.trim().isEmpty) {
      _payload = null;
      _error = null;
      return;
    }
    try {
      _payload = buildVietQrPayload(
        bankBin: bank.bin,
        accountNumber: _accountNumber,
        amount: _amount,
        note: _note,
      );
      _error = null;
    } on VietQrError catch (e) {
      _payload = null;
      _error = e.message;
    }
  }
}
