import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/security/app_lock_gate.dart';
import 'features/settings/settings_provider.dart';
import 'services/auto_sync_service.dart';
import 'services/notification_service.dart';

class MudhakkaratiApp extends StatefulWidget {
  const MudhakkaratiApp({super.key});

  @override
  State<MudhakkaratiApp> createState() => _MudhakkaratiAppState();
}

class _MudhakkaratiAppState extends State<MudhakkaratiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // مزامنة عند الإقلاع (إن كانت مفعّلة ومرّت المدة).
    AutoSyncService.instance.maybeSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // مزامنة عند تصغير/إغلاق التطبيق.
    if (state == AppLifecycleState.paused) {
      AutoSyncService.instance.maybeSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Alaoufi Notes',
      navigatorKey: appNavigatorKey,
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
        FlutterQuillLocalizations.delegate,
      ],
      // ملاحظة: FlutterQuillLocalizations.delegate ثابت (const) لذا تبقى القائمة const.
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
