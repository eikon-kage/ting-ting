import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';

/// Bottom sheet to choose light, dark or the phone's setting. Applies on tap,
/// so the user sees the change behind the sheet before closing it.
Future<void> showThemePicker(BuildContext context) => showModalBottomSheet(
  context: context,
  builder: (_) => const _ThemePicker(),
);

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  static const _options = [
    (ThemeMode.dark, Icons.dark_mode_outlined, 'Tối'),
    (ThemeMode.light, Icons.light_mode_outlined, 'Sáng'),
    (ThemeMode.system, Icons.brightness_auto_outlined, 'Theo máy'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Giao diện',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final (mode, icon, label) in _options)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                selected: controller.mode == mode,
                selectedColor: scheme.primary,
                trailing: controller.mode == mode
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => controller.setMode(mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
