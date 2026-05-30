import 'package:flutter/material.dart';

/// يبني سمات التطبيق (نهاري/ليلي) انطلاقًا من لون أساسي وحجم خط.
class AppTheme {
  AppTheme._();

  static ThemeData light(Color seed, double fontScale,
          [String fontFamily = 'Cairo']) =>
      _build(seed, Brightness.light, fontScale, fontFamily);

  static ThemeData dark(Color seed, double fontScale,
          [String fontFamily = 'Cairo']) =>
      _build(seed, Brightness.dark, fontScale, fontFamily);

  static ThemeData _build(Color seed, Brightness brightness, double fontScale,
      String fontFamily) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isDark = brightness == Brightness.dark;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121214) : const Color(0xFFF6F7F9),
      brightness: brightness,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: base.scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.bold,
          fontSize: 22 * fontScale,
          color: scheme.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: _scaleTextTheme(base.textTheme, fontScale),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static TextTheme _scaleTextTheme(TextTheme t, double s) {
    TextStyle? sc(TextStyle? style) =>
        style == null ? null : style.copyWith(fontSize: (style.fontSize ?? 14) * s);
    return t.copyWith(
      displayLarge: sc(t.displayLarge),
      displayMedium: sc(t.displayMedium),
      displaySmall: sc(t.displaySmall),
      headlineLarge: sc(t.headlineLarge),
      headlineMedium: sc(t.headlineMedium),
      headlineSmall: sc(t.headlineSmall),
      titleLarge: sc(t.titleLarge),
      titleMedium: sc(t.titleMedium),
      titleSmall: sc(t.titleSmall),
      bodyLarge: sc(t.bodyLarge),
      bodyMedium: sc(t.bodyMedium),
      bodySmall: sc(t.bodySmall),
      labelLarge: sc(t.labelLarge),
      labelMedium: sc(t.labelMedium),
      labelSmall: sc(t.labelSmall),
    );
  }
}
