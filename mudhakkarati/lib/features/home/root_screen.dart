import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/backup_service.dart';
import '../../services/sync/sync_service.dart';
import '../reminders/reminders_provider.dart';
import 'home_screen.dart';
import 'notes_provider.dart';

/// الجذر: يهيّئ البيانات ثم يعرض الصفحة الرئيسية (التي تحوي القائمة الجانبية).
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notes = context.read<NotesProvider>();
      notes.init();
      context.read<RemindersProvider>().refresh();
      // نسخة احتياطية تلقائية إن حان موعدها (بلا انتظار حتى لا تُعيق الواجهة).
      BackupService.instance.maybeRunAutoBackup();
      // مزامنة سحابية تلقائية إن كانت مفعّلة (بلا انتظار)، ثم تحديث القائمة.
      SyncService.instance.maybeAutoSync().then((r) {
        if (r != null && r.ok) {
          notes.loadCategories();
          notes.refresh();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
