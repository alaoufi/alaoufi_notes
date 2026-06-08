import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      context.read<NotesProvider>().init();
      context.read<RemindersProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
