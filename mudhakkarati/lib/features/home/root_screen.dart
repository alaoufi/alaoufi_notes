import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync/sync_service.dart';
import '../reminders/reminders_provider.dart';
import 'home_screen.dart';
import 'notes_provider.dart';

/// الجذر: يهيّئ البيانات ثم يعرض الصفحة الرئيسية (التي تحوي القائمة الجانبية).
///
/// يراقب دورة حياة التطبيق ليُجري **مزامنة سحابية تلقائية** عند الإقلاع وكلّما
/// عاد التطبيق إلى الواجهة (resume)، مع إظهار «تمت المزامنة ✓».
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  bool _syncing = false;
  DateTime? _lastSyncDone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesProvider>().init();
      context.read<RemindersProvider>().refresh();
      // إن أُقلع التطبيق من منبّه حرج (وهو مغلق) ⇒ أظهر شاشة المنبّه فورًا.
      NotificationService.instance.handleLaunch();
      // شبكة أمان ضدّ فقدان الملاحظات: نُفعّل النسخ التلقائي اليومي افتراضيًا عند
      // أول تشغيل (مرّة واحدة)، ثم ننشئ نسخة إن حان موعدها — كلّه في الخلفية.
      BackupService.instance
          .ensureDefaultAutoBackup()
          .then((_) => BackupService.instance.maybeRunAutoBackup());
      // مزامنة أولى عند الإقلاع.
      _autoSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // كلّما عاد التطبيق إلى الواجهة، حاول مزامنة تلقائية.
    if (state == AppLifecycleState.resumed) {
      _autoSync();
    }
  }

  /// مزامنة تلقائية في الخلفية مع شريط خفيف في الأعلى (لا تُعطّل العمل).
  Future<void> _autoSync() async {
    if (_syncing) return;
    // تجنّب التكرار السريع عند تعدّد أحداث الاستئناف خلال ثوانٍ.
    if (_lastSyncDone != null &&
        DateTime.now().difference(_lastSyncDone!) < const Duration(seconds: 8)) {
      return;
    }
    final svc = SyncService.instance;
    if (!await svc.autoSync()) return;
    if (!await svc.isConfigured()) return;

    _syncing = true;
    svc.status.value =
        const SyncStatus(SyncUi.syncing, 'جارٍ مزامنة ملاحظاتك…');

    final r = await svc.syncNow();
    _lastSyncDone = DateTime.now();
    _syncing = false;

    // حدّث القائمة بهدوء عند النجاح.
    if (r.ok && mounted) {
      final notes = context.read<NotesProvider>();
      await notes.loadCategories();
      await notes.refresh();
    }

    svc.status.value = r.ok
        ? const SyncStatus(SyncUi.done, 'تمت المزامنة')
        : SyncStatus(SyncUi.error, r.message);
    // إخفاء الشريط تلقائيًا بعد لحظة.
    Future.delayed(Duration(seconds: r.ok ? 2 : 4), () {
      if (svc.status.value.state != SyncUi.syncing) {
        svc.status.value = const SyncStatus(SyncUi.idle);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
