import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../../services/notification_service.dart';

/// مكان زرّ صفحة «معلومات عامة».
enum InfoPlacement { tab, menu, drawer }

/// إعدادات المظهر واللغة والعرض. تُحفظ محليًا في SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = AppColors.defaultSeed;
  double _fontScale = 1.0;
  String _fontFamily = 'Cairo';
  bool _hideSelectionMenu = false;
  InfoPlacement _infoPlacement = InfoPlacement.tab;
  NoteLayout _layout = NoteLayout.grid;
  Locale _locale = const Locale('ar');
  String _alarmTone = 'alarm';
  int _snoozeMinutes = 10; // مدّة الغفوة بالدقائق (0 = بلا غفوة)
  String? _customToneUri; // رابط نغمة مخصّصة من الجهاز (عند alarmTone=custom)
  String? _customToneTitle; // اسم النغمة المخصّصة للعرض
  int _customToneSeq = 0; // معرّف متزايد لقناة النغمة المخصّصة

  // ---- الافتراضي للملاحظات الجديدة ----
  int? _defaultNoteColor; // null = اللون الافتراضي للسمة
  String? _defaultGradient; // تدرّج لوني افتراضي (مُرمَّز) أو null
  int _defaultBgStyle = 0; // 0..7 (نمط صفحة الملاحظة)
  String _noteFontFamily = 'Cairo'; // خط متن الملاحظة
  double _noteFontSize = 16; // حجم خط المتن
  double _noteLineHeight = 1.6; // تباعد الأسطر (مضاعف ارتفاع السطر)
  bool _noteBold = false; // خط متن غامق افتراضيًّا
  // ---- تنسيق تسطير الصفحة ----
  double _ruleThickness = 1.0; // سماكة الأسطر
  double _ruleOpacity = 0.12; // شفافية الأسطر (0..1)
  bool _ruleOnLine = true; // الكتابة على السطر (true) أو بين السطرين (false)
  bool _privacyMode = false; // إخفاء معاينات الملاحظات بسرعة

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  double get fontScale => _fontScale;
  String get fontFamily => _fontFamily;
  bool get hideSelectionMenu => _hideSelectionMenu;
  InfoPlacement get infoPlacement => _infoPlacement;
  NoteLayout get layout => _layout;
  Locale get locale => _locale;
  String get alarmTone => _alarmTone;
  int get snoozeMinutes => _snoozeMinutes;
  String? get customToneUri => _customToneUri;
  String? get customToneTitle => _customToneTitle;

  int? get defaultNoteColor => _defaultNoteColor;
  String? get defaultGradient => _defaultGradient;
  int get defaultBgStyle => _defaultBgStyle;
  String get noteFontFamily => _noteFontFamily;
  double get noteFontSize => _noteFontSize;
  double get noteLineHeight => _noteLineHeight;
  bool get noteBold => _noteBold;
  double get ruleThickness => _ruleThickness;
  double get ruleOpacity => _ruleOpacity;
  bool get ruleOnLine => _ruleOnLine;
  bool get privacyMode => _privacyMode;

  /// الخطوط العربية المتاحة لاختيار الخط الافتراضي للتطبيق.
  static const fontFamilies = <String>[
    'Cairo',
    'Tajawal',
    'Almarai',
    'IBM Plex Sans Arabic',
    'Readex Pro',
    'Mada',
    'Changa',
    'Vazirmatn',
    'El Messiri',
    'Markazi Text',
    'Lemonada',
    'Harmattan',
    'Reem Kufi',
    'Kufam',
    'Marhey',
    'Noto Naskh Arabic',
    'Amiri',
    'Scheherazade New',
    'Aref Ruqaa',
    'Lalezar',
    'Rakkas',
    'Jomhuria',
    'Gulzar',
    'Qahiri',
    'Noto Kufi Arabic',
    'Noto Sans Arabic',
    'Rubik',
    'Baloo Bhaijaan 2',
    'Lateef',
    'Mirza',
    'Katibeh',
    'Alkalami',
    'Aref Ruqaa Ink',
    'Amiri Quran',
    'Noto Nastaliq Urdu',
  ];

  static const _kMode = 'theme_mode';
  static const _kSeed = 'seed_color';
  static const _kFont = 'font_scale';
  static const _kFontFamily = 'font_family';
  static const _kHideSelMenu = 'hide_selection_menu';
  static const _kInfoPlacement = 'info_placement';
  static const _kLayout = 'note_layout';
  static const _kLocale = 'locale';
  static const _kTone = 'alarm_tone';
  static const _kCustomToneUri = 'custom_tone_uri';
  static const _kCustomToneTitle = 'custom_tone_title';
  static const _kCustomToneSeq = 'custom_tone_seq';
  static const _kDefColor = 'def_note_color';
  static const _kDefGradient = 'def_gradient';
  static const _kDefBgStyle = 'def_bg_style';
  static const _kNoteFont = 'note_font_family';
  static const _kNoteFontSize = 'note_font_size';
  static const _kNoteLineHeight = 'note_line_height';
  static const _kNoteBold = 'note_bold';
  static const _kRuleThickness = 'rule_thickness';
  static const _kRuleOpacity = 'rule_opacity';
  static const _kRuleOnLine = 'rule_on_line';
  static const _kPrivacyMode = 'privacy_mode';

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
    final fam = prefs.getString(_kFontFamily);
    if (fam != null && fontFamilies.contains(fam)) _fontFamily = fam;
    _hideSelectionMenu = prefs.getBool(_kHideSelMenu) ?? false;
    final ip = prefs.getString(_kInfoPlacement);
    _infoPlacement = InfoPlacement.values
        .firstWhere((e) => e.name == ip, orElse: () => InfoPlacement.tab);
    _layout = prefs.getString(_kLayout) == 'list' ? NoteLayout.list : NoteLayout.grid;
    _locale = Locale(prefs.getString(_kLocale) ?? 'ar');
    _alarmTone = prefs.getString(_kTone) ?? 'alarm';
    _snoozeMinutes = prefs.getInt('snooze_minutes') ?? 10;
    NotificationService.instance.snoozeMinutes = _snoozeMinutes;
    _customToneUri = prefs.getString(_kCustomToneUri);
    _customToneTitle = prefs.getString(_kCustomToneTitle);
    _customToneSeq = prefs.getInt(_kCustomToneSeq) ?? 0;
    NotificationService.instance.tone = _alarmTone;
    if (_alarmTone == 'custom' && _customToneUri != null) {
      await NotificationService.instance
          .setCustomTone(_customToneUri, seq: _customToneSeq);
    }

    _defaultNoteColor =
        prefs.containsKey(_kDefColor) ? prefs.getInt(_kDefColor) : null;
    _defaultGradient = prefs.getString(_kDefGradient);
    _defaultBgStyle = prefs.getInt(_kDefBgStyle) ?? 0;
    final nf = prefs.getString(_kNoteFont);
    if (nf != null && fontFamilies.contains(nf)) _noteFontFamily = nf;
    _noteFontSize = prefs.getDouble(_kNoteFontSize) ?? 16;
    _noteLineHeight = prefs.getDouble(_kNoteLineHeight) ?? 1.6;
    _noteBold = prefs.getBool(_kNoteBold) ?? false;
    _ruleThickness = prefs.getDouble(_kRuleThickness) ?? 1.0;
    _ruleOpacity = prefs.getDouble(_kRuleOpacity) ?? 0.12;
    _ruleOnLine = prefs.getBool(_kRuleOnLine) ?? true;
    _privacyMode = prefs.getBool(_kPrivacyMode) ?? false;

    notifyListeners();
  }

  Future<void> setPrivacyMode(bool v) async {
    _privacyMode = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrivacyMode, v);
  }

  Future<void> setDefaultNoteColor(int? color) async {
    _defaultNoteColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_kDefColor);
    } else {
      await prefs.setInt(_kDefColor, color);
    }
  }

  Future<void> setDefaultGradient(String? gradient) async {
    _defaultGradient = gradient;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (gradient == null) {
      await prefs.remove(_kDefGradient);
    } else {
      await prefs.setString(_kDefGradient, gradient);
    }
  }

  Future<void> setDefaultBgStyle(int style) async {
    _defaultBgStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDefBgStyle, style);
  }

  Future<void> setNoteFontFamily(String family) async {
    _noteFontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNoteFont, family);
  }

  Future<void> setNoteFontSize(double size) async {
    _noteFontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kNoteFontSize, size);
  }

  Future<void> setNoteLineHeight(double h) async {
    _noteLineHeight = h;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kNoteLineHeight, h);
  }

  Future<void> setNoteBold(bool v) async {
    _noteBold = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNoteBold, v);
  }

  Future<void> setRuleThickness(double t) async {
    _ruleThickness = t;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRuleThickness, t);
  }

  Future<void> setRuleOpacity(double o) async {
    _ruleOpacity = o;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRuleOpacity, o);
  }

  Future<void> setRuleOnLine(bool v) async {
    _ruleOnLine = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRuleOnLine, v);
  }

  Future<void> setAlarmTone(String tone) async {
    _alarmTone = tone;
    NotificationService.instance.tone = tone;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTone, tone);
  }

  /// مدّة الغفوة بالدقائق (0 = بلا غفوة).
  Future<void> setSnoozeMinutes(int minutes) async {
    _snoozeMinutes = minutes;
    NotificationService.instance.snoozeMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('snooze_minutes', minutes);
  }

  /// يضبط نغمة مخصّصة مختارة من نغمات الجهاز ([uri] رابطها، [title] اسمها).
  Future<void> setCustomTone(String uri, String? title) async {
    _customToneSeq++; // معرّف قناة جديد عند كل تغيير (قنوات أندرويد ثابتة الصوت)
    _customToneUri = uri;
    _customToneTitle = title;
    _alarmTone = 'custom';
    await NotificationService.instance.setCustomTone(uri, seq: _customToneSeq);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTone, 'custom');
    await prefs.setString(_kCustomToneUri, uri);
    await prefs.setInt(_kCustomToneSeq, _customToneSeq);
    if (title != null) {
      await prefs.setString(_kCustomToneTitle, title);
    } else {
      await prefs.remove(_kCustomToneTitle);
    }
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

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontFamily, family);
  }

  Future<void> setHideSelectionMenu(bool hide) async {
    _hideSelectionMenu = hide;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideSelMenu, hide);
  }

  Future<void> setInfoPlacement(InfoPlacement placement) async {
    _infoPlacement = placement;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInfoPlacement, placement.name);
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
