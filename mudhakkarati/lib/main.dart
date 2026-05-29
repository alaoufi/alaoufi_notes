import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/note_repository.dart';
import 'data/repositories/reminder_repository.dart';
import 'features/home/notes_provider.dart';
import 'features/reminders/reminders_provider.dart';
import 'features/settings/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/vault_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة بيانات التواريخ (للتقويم بالعربية والإنجليزية).
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  // تهيئة مفتاح تشفير كلمات المرور (يُخزَّن في تخزين الجهاز الآمن).
  await VaultService.instance.ensureKey();

  // تهيئة الإشعارات المحلية (بدون إنترنت).
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();

  final db = AppDatabase.instance;
  final noteRepo = NoteRepository(db);
  final categoryRepo = CategoryRepository(db);
  final reminderRepo = ReminderRepository(db);

  final settings = SettingsProvider();
  await settings.load();

  final notesProvider = NotesProvider(noteRepo, categoryRepo);
  final remindersProvider = RemindersProvider(reminderRepo, noteRepo);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: notesProvider),
        ChangeNotifierProvider.value(value: remindersProvider),
      ],
      child: const MudhakkaratiApp(),
    ),
  );
}
