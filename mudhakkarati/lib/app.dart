import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/security/app_lock_gate.dart';
import 'features/settings/settings_provider.dart';

class MudhakkaratiApp extends StatelessWidget {
  const MudhakkaratiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Alaoufi Notes',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.light(settings.seedColor, settings.fontScale),
      darkTheme: AppTheme.dark(settings.seedColor, settings.fontScale),
      locale: settings.locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        SDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ضمان اتجاه RTL للعربية.
      builder: (context, child) {
        final isRtl = settings.locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      home: const AppLockGate(),
    );
  }
}
