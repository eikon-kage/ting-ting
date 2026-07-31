import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns the QR card drawn on screen into a PNG and pushes it out of the app.
///
/// Android gives an app nowhere it can simply drop a file the user will find
/// later, so "tải về" ends at the system share sheet — the same road the backup
/// file takes. From there the user picks Ảnh, Tệp, Zalo, wherever they want it.
class QrFiles {
  QrFiles._();

  static final QrFiles instance = QrFiles._();

  /// Repaints whatever [RepaintBoundary] sits at [key] into PNG bytes.
  ///
  /// Renders at three times its on-screen size: the image gets forwarded,
  /// reprinted and photographed off other people's screens, and a QR whose
  /// modules have gone soft stops scanning.
  ///
  /// Returns `null` when the card is not currently in the tree — the caller has
  /// to make sure it is on screen before asking.
  Future<Uint8List?> renderPng(GlobalKey key, {double pixelRatio = 3}) async {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Writes [png] to a temp file and opens the share sheet on it.
  ///
  /// Returns `false` when the user backs out without picking anything.
  Future<bool> shareQr(
    Uint8List png, {
    required String fileName,
    required String subject,
    String? text,
  }) async {
    // Cache directory: the system clears it on its own, so a picture of a bank
    // account does not sit around on disk after the user has saved it where
    // they wanted it.
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, fileName);
    await File(path).writeAsBytes(png, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'image/png')],
        subject: subject,
        text: text,
      ),
    );
    return result.status == ShareResultStatus.success;
  }
}
