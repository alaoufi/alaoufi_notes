import 'package:flutter/material.dart';

/// لوحة ألوان التطبيق وهويته البصرية الخاصة (مختلفة عن أي تطبيق آخر).
class AppColors {
  AppColors._();

  /// ألوان السمة (Theme) المتاحة للاختيار من الإعدادات.
  static const Map<String, Color> themeSeeds = {
    'أخضر زمردي': Color(0xFF2E7D6B),
    'أزرق هادئ': Color(0xFF3F6FB5),
    'بنفسجي': Color(0xFF7E57C2),
    'برتقالي دافئ': Color(0xFFE8772E),
    'وردي': Color(0xFFC2476B),
    'رمادي أنيق': Color(0xFF546E7A),
  };

  static const Color defaultSeed = Color(0xFF2E7D6B);

  /// ألوان بطاقات الملاحظات (هادئة ومريحة للعين، نهارية).
  static const List<Color> noteColorsLight = [
    Color(0xFFFFFFFF), // أبيض (افتراضي)
    Color(0xFFFFF1B8), // أصفر فاتح
    Color(0xFFFFD9C7), // مشمشي
    Color(0xFFFFCDD2), // وردي
    Color(0xFFE1BEE7), // بنفسجي فاتح
    Color(0xFFC8E6C9), // أخضر فاتح
    Color(0xFFB3E5FC), // أزرق سماوي
    Color(0xFFD7CCC8), // بيج
  ];

  /// نسخ داكنة من نفس الألوان للوضع الليلي.
  static const List<Color> noteColorsDark = [
    Color(0xFF2A2A2E), // رمادي داكن (افتراضي)
    Color(0xFF4A431F), // أصفر داكن
    Color(0xFF4A2E20), // مشمشي داكن
    Color(0xFF4A2226), // وردي داكن
    Color(0xFF3A2540), // بنفسجي داكن
    Color(0xFF1F3A22), // أخضر داكن
    Color(0xFF173947), // أزرق داكن
    Color(0xFF332B26), // بيج داكن
  ];

  /// يحوّل لون بطاقة (نهاري) إلى ما يناسب الوضع الحالي.
  static Color resolveNoteColor(int? stored, bool isDark) {
    if (stored == null) {
      return isDark ? noteColorsDark.first : noteColorsLight.first;
    }
    final index = noteColorsLight.indexWhere((c) => c.value == stored);
    if (index == -1) {
      return Color(stored);
    }
    return isDark ? noteColorsDark[index] : noteColorsLight[index];
  }
}
