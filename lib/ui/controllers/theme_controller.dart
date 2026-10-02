import 'package:flutter/material.dart';

import '../../data/data_store.dart';

/// Which scheme the app shows: light, dark, or whatever the phone is set to.
///
/// Read once before the first frame so the app does not open dark and then
/// flip. Lives for the whole app, so nobody disposes it.
class ThemeController extends ChangeNotifier {
  ThemeController({DataStore? data}) : _data = data ?? DataStore.instance;

  static final ThemeController instance = ThemeController();

  final DataStore _data;

  /// Dark until told otherwise: it is what the app shipped with, so a user who
  /// never opens the picker sees no change.
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  Future<void> init() async {
    final saved = await _data.settings.readThemeMode();
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.dark,
    );
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _data.settings.writeThemeMode(mode.name);
  }
}
