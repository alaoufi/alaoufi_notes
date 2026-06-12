import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/reminder.dart';
import '../../services/ringtone_picker.dart';
import '../../services/tone_preview.dart';
import '../settings/settings_provider.dart';
import 'reminders_provider.dart';

const _toneNames = {
  'alarm': 'إنذار',
  'chime': 'لطيفة',
  'bell': 'جرس',
  'forest': 'غابة 🌳',
  'birds': 'طيور 🐦',
  'water': 'ماء 💧',
  'rain': 'مطر 🌧️',
  'ocean': 'محيط 🌊',
};

/// حوار إنشاء/تعديل **تنبيه مستقلّ** (غير مرتبط بملاحظة): عنوان + وقت + تكرار + نغمة.
Future<void> showStandaloneReminderDialog(BuildContext context,
    {Reminder? existing}) async {
  final s = S.of(context);
  final provider = context.read<RemindersProvider>();
  final settings = context.read<SettingsProvider>();
  final titleCtrl =
      TextEditingController(text: existing?.title ?? '');
  DateTime date = existing?.time ?? DateTime.now().add(const Duration(hours: 1));
  TimeOfDay time = TimeOfDay.fromDateTime(date);
  ReminderRepeat repeat = existing?.repeat ?? ReminderRepeat.once;

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
                Text(existing == null ? 'تنبيه جديد' : 'تعديل التنبيه',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'عنوان التنبيه',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
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
                    final picked = await showTimePicker(
                        context: context, initialTime: time);
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
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconButton(
                    tooltip: 'سماع',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () {
                      if (settings.alarmTone != 'custom') {
                        TonePreview.play(settings.alarmTone);
                      }
                    },
                  ),
                  title: const Text('النغمة'),
                  subtitle: Text(settings.alarmTone == 'custom'
                      ? (settings.customToneTitle ?? 'نغمة مخصّصة')
                      : (_toneNames[settings.alarmTone] ?? 'إنذار')),
                  trailing: DropdownButton<String>(
                    value: _toneNames.containsKey(settings.alarmTone)
                        ? settings.alarmTone
                        : 'custom',
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final e in _toneNames.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                      if (settings.alarmTone == 'custom')
                        DropdownMenuItem(
                            value: 'custom',
                            child: Text(settings.customToneTitle ?? 'مخصّصة 🎵',
                                overflow: TextOverflow.ellipsis)),
                      const DropdownMenuItem(
                          value: 'pick', child: Text('من الجهاز… 📱')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      if (v == 'pick') {
                        final uri = await RingtonePicker.pick(
                            current: settings.customToneUri);
                        if (uri != null) {
                          final t = await RingtonePicker.title(uri);
                          await settings.setCustomTone(uri, t);
                        }
                      } else {
                        await settings.setAlarmTone(v);
                      }
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 12),
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
                        await provider.setStandalone(
                            combined(), repeat, titleCtrl.text,
                            existing: existing);
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
