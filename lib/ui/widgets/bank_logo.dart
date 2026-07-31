import 'package:flutter/material.dart';

import '../../domain/vietqr_banks.dart';

/// Logo ngân hàng, mặc định đặt trong một khung trắng.
///
/// Logo NAPAS phát hành là chữ sẫm trên nền trong suốt, thả thẳng vào theme tối
/// là mất hút. Khung trắng bo góc giữ chúng đọc được ở cả hai theme — cũng là
/// cách mọi app ngân hàng đang hiển thị logo của nhau. Chỗ nào vốn đã nền trắng
/// thì tắt khung đi bằng [framed].
class BankLogo extends StatelessWidget {
  const BankLogo(this.bank, {super.key, this.height = 32, this.framed = true});

  final VietQrBank bank;

  /// Chiều cao cả khung. Bề ngang tự suy ra, xem [_ratio].
  final double height;

  final bool framed;

  /// File logo của NAPAS đều là 831x311, nên tỉ lệ cứng giữ mọi ngân hàng cùng
  /// một khuôn thay vì mỗi dòng danh sách rộng một kiểu.
  static const double _ratio = 2.7;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      bank.logoAsset,
      fit: BoxFit.contain,
      // Ngân hàng mới thêm mà quên bỏ file logo vào thì vẫn phải ra một dòng
      // bấm được, không phải ô đỏ giữa danh sách.
      errorBuilder: (context, error, stack) => Icon(
        Icons.account_balance_rounded,
        size: height * 0.6,
        color: const Color(0xFF6B6B72),
      ),
    );
    if (!framed) {
      return SizedBox(height: height, width: height * _ratio, child: image);
    }
    return Container(
      height: height,
      width: height * _ratio,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE3E3E8)),
      ),
      child: image,
    );
  }
}
