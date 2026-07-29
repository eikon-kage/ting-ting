import 'dart:async';

import 'package:flutter/material.dart';

import 'services/digest_alerts.dart';
import 'services/summary_widget.dart';
import 'services/txn_alerts.dart';
import 'ui/controllers/category_catalog.dart';
import 'ui/root_shell.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TxnAlerts.instance.init();
  // Danh sách nhóm phải sẵn sàng trước khi có màn nào vẽ ô chọn nhóm.
  await CategoryCatalog.instance.init();
  // Không chờ: widget ngoài màn hình chính cập nhật xong lúc nào cũng được,
  // đừng để nó làm chậm khung hình đầu tiên.
  unawaited(SummaryWidget.instance.init());
  // Lời nhắc sáng thứ Hai được hệ thống giữ, chỉ cần hẹn lại cho chắc.
  unawaited(DigestAlerts.instance.init());
  runApp(const TingTingApp());
}

class TingTingApp extends StatelessWidget {
  const TingTingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ting Ting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const RootShell(),
    );
  }
}
