import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/backup_service.dart';
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
      // نسخة احتياطية تلقائية إن حان موعدها (بلا انتظار حتى لا تُعيق الواجهة).
      BackupService.instance.maybeRunAutoBackup();
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

  /// مزامنة تلقائية مع تغذية راجعة مرئية (إن كانت مفعّلة ومُهيّأة).
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
    if (!mounted) return;

    _syncing = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('جارٍ المزامنة السحابية…'),
      duration: Duration(seconds: 2),
    ));

    final r = await svc.syncNow();
    _lastSyncDone = DateTime.now();
    _syncing = false;
    if (!mounted) return;

    if (r.ok) {
      final notes = context.read<NotesProvider>();
      await notes.loadCategories();
      await notes.refresh();
      if (!mounted) return;
    }

    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(r.ok ? 'تمت المزامنة ✓' : r.message),
      backgroundColor: r.ok ? null : Theme.of(context).colorScheme.error,
      duration: Duration(seconds: r.ok ? 2 : 4),
    ));
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
