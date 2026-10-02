import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ting_ting/ui/controllers/theme_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('a picked theme survives a restart', () async {
    await ThemeController().setMode(ThemeMode.light);

    final reopened = ThemeController();
    await reopened.init();
    expect(reopened.mode, ThemeMode.light);

    await reopened.setMode(ThemeMode.system);
    final again = ThemeController();
    await again.init();
    expect(again.mode, ThemeMode.system);
  });
}
