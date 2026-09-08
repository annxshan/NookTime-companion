import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const String keyThemeMode = 'theme_mode';
  static const String keyLegacyThemeMode = 'app_theme_mode';
  static const String keyPrimarySeedColor = 'primary_seed_color';
  static const String keyIsCustomColor = 'is_custom_color';

  static const Color defaultSeedColor = Color(0xFF6C5CE7);

  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = defaultSeedColor;
  bool _isCustomColor = false;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get isCustomColor => _isCustomColor;

  ThemeData? _lightThemeCache;
  ThemeData? _darkThemeCache;

  ThemeData get lightTheme => _lightThemeCache ??= AppTheme.lightTheme(_seedColor);
  ThemeData get darkTheme => _darkThemeCache ??= AppTheme.darkTheme(_seedColor);

  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() => instance;

  ThemeController._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;

    final savedMode = prefs.getString(keyThemeMode) ?? prefs.getString(keyLegacyThemeMode);
    if (savedMode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedMode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    final savedColorVal = prefs.getInt(keyPrimarySeedColor);
    if (savedColorVal != null) {
      _seedColor = Color(savedColorVal);
    } else {
      _seedColor = defaultSeedColor;
    }

    _isCustomColor = prefs.getBool(keyIsCustomColor) ?? false;
    _lightThemeCache = null;
    _darkThemeCache = null;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    _saveThemeMode(mode);
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';

    await prefs.setString(keyThemeMode, modeStr);
    await prefs.setString(keyLegacyThemeMode, modeStr);
  }

  void setSeedColor(Color color, {bool isCustom = false}) {
    if (_seedColor.toARGB32() == color.toARGB32() && _isCustomColor == isCustom) return;

    _seedColor = color;
    _isCustomColor = isCustom;
    _lightThemeCache = null;
    _darkThemeCache = null;
    notifyListeners();

    _saveSeedColor(color, isCustom: isCustom);
  }

  Future<void> _saveSeedColor(Color color, {bool isCustom = false}) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setInt(keyPrimarySeedColor, color.toARGB32());
    await prefs.setBool(keyIsCustomColor, isCustom);
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.dark:
        return 'Dark Theme';
      case ThemeMode.system:
        return 'System Default';
    }
  }
}
