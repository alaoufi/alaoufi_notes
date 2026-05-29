import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';

/// إعدادات المظهر واللغة والعرض. تُحفظ محليًا في SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = AppColors.defaultSeed;
  double _fontScale = 1.0;
  NoteLayout _layout = NoteLayout.grid;
  Locale _locale = const Locale('ar');

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  double get fontScale => _fontScale;
  NoteLayout get layout => _layout;
  Locale get locale => _locale;

  static const _kMode = 'theme_mode';
  static const _kSeed = 'seed_color';
  static const _kFont = 'font_scale';
  static const _kLayout = 'note_layout';
  static const _kLocale = 'locale';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_kMode);
    _themeMode = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final seed = prefs.getInt(_kSeed);
    if (seed != null) _seedColor = Color(seed);
    _fontScale = prefs.getDouble(_kFont) ?? 1.0;
    _layout = prefs.getString(_kLayout) == 'list' ? NoteLayout.list : NoteLayout.grid;
    _locale = Locale(prefs.getString(_kLocale) ?? 'ar');
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, mode.name);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeed, color.value);
  }

  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFont, scale);
  }

  Future<void> setLayout(NoteLayout layout) async {
    _layout = layout;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLayout, layout.name);
  }

  void toggleLayout() {
    setLayout(_layout == NoteLayout.grid ? NoteLayout.list : NoteLayout.grid);
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, locale.languageCode);
  }
}
