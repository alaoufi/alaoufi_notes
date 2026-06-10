import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import '../../widgets/ui_kit.dart';
import '../editor/note_editor_screen.dart';
import 'reminders_provider.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.watch<RemindersProvider>();

    return Scaffold(
      appBar: gradientAppBar(context, s.t('reminders')),
      body: provider.items.isEmpty
          ? _empty(context, s)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.items.length,
              itemBuilder: (context, i) {
                final view = provider.items[i];
                final r = view.reminder;
                final note = view.note;
                return AppCard(
                  child: ListTile(
                    leading: GradientIcon(_repeatIcon(r.repeat)),
                    title: Text(
                      note?.title.isNotEmpty == true
                          ? note!.title
                          : (note?.content ?? 'ملاحظة'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${DateFormat('yyyy/MM/dd – HH:mm').format(r.time)}  •  ${_repeatLabel(s, r.repeat)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => provider.removeReminder(r),
                    ),
                    onTap: note == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    NoteEditorScreen(noteId: note.id),
                              ),
                            ),
                  ),
                );
              },
            ),
    );
  }

  IconData _repeatIcon(ReminderRepeat r) => switch (r) {
        ReminderRepeat.once => Icons.alarm,
        ReminderRepeat.daily => Icons.today,
        ReminderRepeat.weekly => Icons.view_week,
        ReminderRepeat.monthly => Icons.calendar_month,
        ReminderRepeat.yearly => Icons.event_repeat,
      };

  String _repeatLabel(S s, ReminderRepeat r) => switch (r) {
        ReminderRepeat.once => s.t('repeat_once'),
        ReminderRepeat.daily => s.t('repeat_daily'),
        ReminderRepeat.weekly => s.t('repeat_weekly'),
        ReminderRepeat.monthly => s.t('repeat_monthly'),
        ReminderRepeat.yearly => s.t('repeat_yearly'),
      };

  Widget _empty(BuildContext context, S s) => EmptyState(
        icon: Icons.notifications_off_outlined,
        title: s.t('no_reminders'),
      );
}
