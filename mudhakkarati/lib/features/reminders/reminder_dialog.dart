import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import '../../services/ringtone_picker.dart';
import '../../services/tone_preview.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/time_wheel.dart';
import '../settings/settings_provider.dart';
import 'reminders_provider.dart';

/// أيام الأسبوع (تبدأ بالسبت) — القيمة بمعيار DateTime.weekday (الإثنين=1..الأحد=7).
const List<(int, String)> _weekdayDefs = [
  (6, 'السبت'),
  (7, 'الأحد'),
  (1, 'الإثنين'),
  (2, 'الثلاثاء'),
  (3, 'الأربعاء'),
  (4, 'الخميس'),
  (5, 'الجمعة'),
];

/// أسماء النغمات للعرض في منتقي التذكير.
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

String _impLabel(S s, ReminderImportance imp) => switch (imp) {
      ReminderImportance.low => s.t('imp_low'),
      ReminderImportance.medium => s.t('imp_medium'),
      ReminderImportance.high => s.t('imp_high'),
      ReminderImportance.critical => s.t('imp_critical'),
    };

IconData _impIcon(ReminderImportance imp) => switch (imp) {
      ReminderImportance.low => Icons.notifications_none,
      ReminderImportance.medium => Icons.notifications_active_outlined,
      ReminderImportance.high => Icons.vibration,
      ReminderImportance.critical => Icons.crisis_alert,
    };

Color _impColor(ReminderImportance imp) => switch (imp) {
      ReminderImportance.low => const Color(0xFF78909C),
      ReminderImportance.medium => const Color(0xFF42A5F5),
      ReminderImportance.high => const Color(0xFFEF6C00),
      ReminderImportance.critical => const Color(0xFFE53935),
    };

/// حوار لإضافة/تعديل تذكير لملاحظة (تاريخ + وقت + تكرار).
Future<void> showReminderDialog(BuildContext context, Note note) async {
  final s = S.of(context);
  DateTime date = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay time = TimeOfDay.fromDateTime(date);
  ReminderRepeat repeat = ReminderRepeat.once;
  ReminderImportance importance = ReminderImportance.high;
  final Set<int> preAlerts = {}; // دقائق قبل الموعد

  final settings = context.read<SettingsProvider>();

  // حمّل التذكير الحالي إن وُجد.
  final provider = context.read<RemindersProvider>();
  final all = await provider.getAllForNote(note.id!);
  final existing = all.isEmpty ? null : all.first;
  final Set<int> weekdays = {date.weekday};
  if (existing != null) {
    date = existing.time;
    time = TimeOfDay.fromDateTime(existing.time);
    repeat = existing.repeat;
    importance = existing.importance;
    preAlerts.addAll(existing.preAlerts);
    // عند الأسبوعي بأيام متعددة: اجمع أيام كل تذكيرات الملاحظة.
    if (all.length > 1 || existing.repeat == ReminderRepeat.weekly) {
      weekdays
        ..clear()
        ..addAll(all
            .where((r) => r.repeat == ReminderRepeat.weekly)
            .map((r) => r.time.weekday));
      if (weekdays.isEmpty) weekdays.add(date.weekday);
    }
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
                // التاريخ غير مهمّ عند التكرار اليومي/الأسبوعي (يتكرّر بنفسه).
                if (repeat != ReminderRepeat.weekly &&
                    repeat != ReminderRepeat.daily)
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
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 1)),
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
                    final picked = await pickTimeWheel(context, time);
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
                if (repeat == ReminderRepeat.weekly) ...[
                  const SizedBox(height: 12),
                  Text('أيام الأسبوع',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final d in _weekdayDefs)
                        FilterChip(
                          label: Text(d.$2),
                          selected: weekdays.contains(d.$1),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              weekdays.add(d.$1);
                            } else {
                              weekdays.remove(d.$1);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // مستوى الأهمية (يحدّد سلوك التنبيه).
                Text(s.t('importance'),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ReminderImportance.values.map((imp) {
                    return ChoiceChip(
                      avatar: Icon(_impIcon(imp), size: 18, color: _impColor(imp)),
                      label: Text(_impLabel(s, imp)),
                      selected: importance == imp,
                      onSelected: (_) => setState(() => importance = imp),
                    );
                  }).toList(),
                ),
                // تنبيهات مسبقة قبل الموعد (للتذكير لمرّة واحدة).
                if (repeat == ReminderRepeat.once) ...[
                  const SizedBox(height: 12),
                  Text(s.t('pre_alerts'),
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final (mins, label) in const [
                        (5, '5د'),
                        (15, '15د'),
                        (60, 'ساعة'),
                        (1440, 'يوم'),
                      ])
                        FilterChip(
                          label: Text(label),
                          selected: preAlerts.contains(mins),
                          onSelected: (sel) => setState(() {
                            if (sel) {
                              preAlerts.add(mins);
                            } else {
                              preAlerts.remove(mins);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // النغمة بجانب إنشاء التنبيه مباشرة.
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
                          final title = await RingtonePicker.title(uri);
                          await settings.setCustomTone(uri, title);
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
                          if (!await confirmDelete(context,
                              title: 'حذف التذكير؟',
                              message:
                                  'سيُحذف تذكير هذه الملاحظة ولن يُذكّرك بعد الآن.')) {
                            return;
                          }
                          await provider.removeForNote(note.id!);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(s.t('delete')),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        if (repeat == ReminderRepeat.weekly &&
                            weekdays.isNotEmpty) {
                          await provider.setNoteWeekly(note, time, weekdays,
                              importance: importance);
                        } else {
                          await provider.setReminder(note, combined(), repeat,
                              importance: importance,
                              preAlerts: preAlerts.toList()..sort());
                        }
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
