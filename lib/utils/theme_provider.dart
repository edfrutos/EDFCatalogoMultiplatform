import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el modo de tema (claro / oscuro / sistema) de forma persistente.
class ThemeProvider with ChangeNotifier {
  static const _prefKey = 'edf_theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;
  bool get isSystem => _mode == ThemeMode.system;

  /// Carga la preferencia guardada. Llamar en main() antes de runApp.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    _mode = switch (stored) {
      'light'  => ThemeMode.light,
      'dark'   => ThemeMode.dark,
      _        => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> toggle() async {
    await setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Icono representativo del modo actual (para botones de UI).
  IconData get icon => switch (_mode) {
    ThemeMode.dark   => Icons.dark_mode_rounded,
    ThemeMode.light  => Icons.light_mode_rounded,
    ThemeMode.system => Icons.contrast_rounded,
  };

  String get label => switch (_mode) {
    ThemeMode.dark   => 'Modo oscuro',
    ThemeMode.light  => 'Modo claro',
    ThemeMode.system => 'Sistema',
  };
}
