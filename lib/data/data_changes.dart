import 'package:flutter/foundation.dart';

/// Chuông báo "dữ liệu vừa đổi".
///
/// Mọi repository gõ chuông sau khi ghi; controller nào đang hiển thị dữ liệu
/// thì nghe và tự tải lại. Nhờ vậy không màn nào phải nhớ gọi `_load()` sau mỗi
/// lần sửa hay sau mỗi lần đóng màn con.
class DataChanges extends ChangeNotifier {
  void markChanged() => notifyListeners();
}
