import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import 'reminders_provider.dart';

/// حوار لإضافة/تعديل تذكير لملاحظة (تاريخ + وقت + تكرار).
Future<void> showReminderDialog(BuildContext context, Note note) async {
  final s = S.of(context);
  DateTime date = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay time = TimeOfDay.fromDateTime(date);
  ReminderRepeat repeat = ReminderRepeat.once;

  // حمّل التذكير الحالي إن وُجد.
  final provider = context.read<RemindersProvider>();
  final existing = await provider.getForNote(note.id!);
  if (existing != null) {
    date = existing.time;
    time = TimeOfDay.fromDateTime(existing.time);
    repeat = existing.repeat;
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          DateTime combined() => DateTime(
              date.year, date.month, date.day, time.hour, time.minute);

          String repeatLabel(ReminderRepeat r) => switch (r) {
                ReminderRepeat.once => s.t('repeat_once'),
                ReminderRepeat.daily => s.t('repeat_daily'),
                ReminderRepeat.weekly => s.t('repeat_weekly'),
                ReminderRepeat.monthly => s.t('repeat_monthly'),
                ReminderRepeat.yearly => s.t('repeat_yearly'),
              };

          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('add_reminder'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(s.t('pick_date')),
                  subtitle: Text(
                      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text(s.t('pick_time')),
                  subtitle: Text(time.format(context)),
                  onTap: () async {
                    final picked =
                        await showTimePicker(context: context, initialTime: time);
                    if (picked != null) setState(() => time = picked);
                  },
                ),
                const SizedBox(height: 8),
                Text(s.t('repeat'),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ReminderRepeat.values.map((r) {
                    return ChoiceChip(
                      label: Text(repeatLabel(r)),
                      selected: repeat == r,
                      onSelected: (_) => setState(() => repeat = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (existing != null)
                      TextButton.icon(
                        onPressed: () async {
                          await provider.removeReminder(existing);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(s.t('delete')),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await provider.setReminder(note, combined(), repeat);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(s.t('save')),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
