import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/backup.dart';

/// Đưa file ra khỏi app và nhận file từ ngoài vào.
///
/// Android không cho app tự ghi vào thư mục của user. Nên bản sao lưu được
/// viết vào vùng tạm của chính app rồi đẩy qua hộp chia sẻ của hệ thống —
/// user chọn Drive, Files, Zalo hay bất cứ đâu. Cách này cũng đúng tinh thần
/// hơn: bản sao lưu nằm cùng máy với bản gốc thì mất máy vẫn mất cả hai.
class BackupFiles {
  BackupFiles._();

  static final BackupFiles instance = BackupFiles._();

  /// Đuôi file riêng để bản sao lưu không lẫn với đống JSON khác trong Drive.
  static const String backupExtension = 'json';

  /// Ghi bản sao lưu ra file tạm rồi mở hộp chia sẻ.
  ///
  /// Trả về `false` khi user đóng hộp chia sẻ mà không chọn gì.
  Future<bool> shareBackup(BackupData data) async {
    final name = 'tingting-${_stamp(data.createdAt)}.$backupExtension';
    final file = await _writeTemp(name, data.encode());
    return _share(
      file,
      subject: 'Sao lưu Ting Ting ${_stamp(data.createdAt)}',
      text:
          'Bản sao lưu Ting Ting, ${data.rowCount} dòng dữ liệu. '
          'Giữ file này ở nơi khác máy.',
    );
  }

  /// Ghi bảng CSV ra file tạm rồi mở hộp chia sẻ.
  Future<bool> shareCsv(String csv, {required String label}) async {
    final file = await _writeTemp('tingting-$label.csv', csv);
    return _share(file, subject: 'Giao dịch Ting Ting $label');
  }

  /// Cho user chọn một file sao lưu và đọc nội dung ra.
  ///
  /// Trả về `null` khi user không chọn file nào.
  Future<String?> pickBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Bản sao lưu Ting Ting',
          extensions: [backupExtension],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return null;
    return file.readAsString(encoding: utf8);
  }

  /// File tạm nằm trong vùng cache của app: hệ thống tự dọn, và không có bản
  /// sao dữ liệu nào nằm lại lâu dài ngoài chỗ user tự chọn cất.
  Future<XFile> _writeTemp(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, name);
    final file = await File(path).writeAsString(content, encoding: utf8);
    return XFile(file.path);
  }

  Future<bool> _share(XFile file, {required String subject, String? text}) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [file], subject: subject, text: text),
    );
    return result.status == ShareResultStatus.success;
  }

  /// "2026-07-29-1530" — xếp theo tên là xếp theo thời gian.
  static String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}'
        '-${two(at.hour)}${two(at.minute)}';
  }
}
