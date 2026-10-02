import 'package:flutter/material.dart';

/// Tiêu đề thanh trên cùng của một tab: icon app rồi tới tên màn.
///
/// Ảnh là bản sao icon launcher, nên cái user thấy trong app đúng bằng cái họ
/// vừa bấm vào ngoài màn hình chính.
class BrandTitle extends StatelessWidget {
  const BrandTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    // Icon lớn lên theo cỡ chữ hệ thống — để cứng một con số thì ở cỡ chữ to
    // nó teo lại thành hạt đậu bên cạnh dòng tên.
    final side = MediaQuery.textScalerOf(context).scale(28);
    // Chữ ở cỡ 26 của thanh tiêu đề đã ngốn gần hết chiều ngang, nên cộng thêm
    // icon là tràn trên gần như mọi bề ngang máy. Thu nhỏ cả cụm cùng lúc thay
    // vì cắt chữ: máy hẹp thì icon và tên nhỏ đi cùng nhau, máy thường rộng thì
    // không đụng gì tới.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/brand/app_icon.png',
            width: side,
            height: side,
            // Icon là hình vẽ, không phải chữ; máy đọc màn hình đọc tên màn
            // ngay bên cạnh rồi.
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
    );
  }
}
