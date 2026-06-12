import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import '../../widgets/ui_kit.dart';
import '../editor/note_editor_screen.dart';
import 'reminders_provider.dart';
import 'standalone_reminder_dialog.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.watch<RemindersProvider>();
    final standalone =
        provider.items.where((v) => v.reminder.isStandalone).toList();
    final noteLinked =
        provider.items.where((v) => !v.reminder.isStandalone).toList();

    return Scaffold(
      appBar: gradientAppBar(context, s.t('reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStandaloneReminderDialog(context),
        icon: const Icon(Icons.add_alarm),
        label: const Text('تنبيه جديد'),
      ),
      body: provider.items.isEmpty
          ? _empty(context, s)
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 90),
              children: [
                if (standalone.isNotEmpty) ...[
                  _header(context, '⏰ تنبيهات مستقلّة'),
                  for (final v in standalone) _tile(context, s, provider, v),
                ],
                if (noteLinked.isNotEmpty) ...[
                  _header(context, '📝 تنبيهات الملاحظات'),
                  for (final v in noteLinked) _tile(context, s, provider, v),
                ],
              ],
            ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );

  Widget _tile(BuildContext context, S s, RemindersProvider provider,
      ReminderView v) {
    final r = v.reminder;
    final note = v.note;
    final title = r.isStandalone
        ? (r.title?.isNotEmpty == true ? r.title! : 'تنبيه')
        : (note?.title.isNotEmpty == true
            ? note!.title
            : (note?.content ?? 'ملاحظة'));
    return AppCard(
      child: ListTile(
        leading: GradientIcon(_repeatIcon(r.repeat),
            color: r.isStandalone
                ? Theme.of(context).colorScheme.tertiaryContainer
                : null),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${DateFormat('yyyy/MM/dd – HH:mm').format(r.time)}  •  ${_repeatLabel(s, r.repeat)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => provider.removeReminder(r),
        ),
        onTap: r.isStandalone
            ? () => showStandaloneReminderDialog(context, existing: r)
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteEditorScreen(noteId: note!.id),
                  ),
                ),
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
        subtitle: 'أنشئ تنبيهًا مستقلًّا بزرّ «تنبيه جديد»',
      );
}
