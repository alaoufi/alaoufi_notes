import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../widgets/confirm_dialog.dart';
import '../../data/models/enums.dart';
import '../editor/editor_attachments.dart';
import 'alarm_permissions.dart';
import '../../data/models/reminder.dart';
import '../../services/ringtone_picker.dart';
import '../../services/tone_preview.dart';
import '../../widgets/time_wheel.dart';
import '../settings/settings_provider.dart';
import '../sounds/sound_catalog.dart';
import 'reminder_helpers.dart';
import 'reminders_provider.dart';

/// نوع المنبّه — يُغيّر الحقول الظاهرة والإعدادات الافتراضية.
enum ReminderKind { general, medication, appointment, occasion }

extension ReminderKindX on ReminderKind {
  String get label => switch (this) {
        ReminderKind.general => 'عام',
        ReminderKind.medication => 'دواء',
        ReminderKind.appointment => 'موعد',
        ReminderKind.occasion => 'مناسبة',
      };

  IconData get icon => switch (this) {
        ReminderKind.general => Icons.notifications_active_outlined,
        ReminderKind.medication => Icons.medication_outlined,
        ReminderKind.appointment => Icons.event_outlined,
        ReminderKind.occasion => Icons.celebration_outlined,
      };

  String get emoji => switch (this) {
        ReminderKind.general => '',
        ReminderKind.medication => '💊 ',
        ReminderKind.appointment => '📅 ',
        ReminderKind.occasion => '🎉 ',
      };

  String get titleLabel => switch (this) {
        ReminderKind.general => 'عنوان التنبيه',
        ReminderKind.medication => 'اسم الدواء',
        ReminderKind.appointment => 'عنوان الموعد',
        ReminderKind.occasion => 'المناسبة',
      };
}

/// وصف ودّي لفاصل الجرعات: «كل N يوم» = جرعة ثم (N-1) راحة.
String _intervalHint(int n) {
  final rest = n - 1;
  final r = switch (rest) {
    1 => 'يوم',
    2 => 'يومين',
    _ => '$rest أيام',
  };
  return 'يوم بعد $r';
}

/// رابط بحث خرائط جوجل لنصّ المكان (لاختيار الموقع ونسخ رابطه).
Uri _mapsSearchUri(String query) {
  final q = Uri.encodeComponent(query.trim().isEmpty ? 'موقع' : query.trim());
  return Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
}

/// يفتح رابطًا في تطبيق خارجي (الخرائط/المتصفّح) بأمان.
Future<void> _openExternal(Uri uri) async {
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {/* لا يوجد تطبيق يفتح الرابط */}
}

/// يختار مرفق الدعوة (صورة أو PDF) وينسخه لمجلد المرفقات. يعيد المسار أو null.
Future<String?> _pickInvitation(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: const Text('صورة'),
          onTap: () => Navigator.pop(context, 'image'),
        ),
        ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined),
          title: const Text('PDF'),
          onTap: () => Navigator.pop(context, 'pdf'),
        ),
      ]),
    ),
  );
  if (choice == 'image' && context.mounted) {
    return EditorAttachments.pickImage(context);
  }
  if (choice == 'pdf') return EditorAttachments.pickPdf();
  return null;
}

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

/// حوار إنشاء/تعديل **تنبيه مستقلّ** (غير مرتبط بملاحظة): عنوان + وقت + تكرار + نغمة.
Future<void> showStandaloneReminderDialog(BuildContext context,
    {Reminder? existing}) async {
  final s = S.of(context);
  final provider = context.read<RemindersProvider>();
  final settings = context.read<SettingsProvider>();
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  DateTime date = existing?.time ?? DateTime.now().add(const Duration(hours: 1));
  TimeOfDay time = TimeOfDay.fromDateTime(date);
  ReminderRepeat repeat = existing?.repeat ?? ReminderRepeat.once;
  // التنبيه المستقلّ منبّه «حقيقيّ» ⇒ نجعله حرجًا افتراضيًّا (شاشة كاملة +
  // أعلى موثوقية + إصرار حتى التأكيد). يمكن للمستخدم خفض المستوى إن أراد.
  ReminderImportance importance =
      existing?.importance ?? ReminderImportance.critical;
  // تنبيه جديد: نبدأ بقيمة «قبل الوقت» الافتراضية من الإعدادات (إن وُجدت).
  final Set<int> preAlerts = {
    ...?existing?.preAlerts,
    if (existing == null && settings.defaultPreAlert > 0)
      settings.defaultPreAlert,
  };
  final Set<int> weekdays = {date.weekday};
  // نوع المنبّه + حقول خاصّة بكل نوع (جرعة الدواء / مكان الموعد + رابط خرائط).
  // عند تعديل تنبيه له موقع محفوظ، نبدأ بنوع «موعد» لإظهار حقول المكان.
  final bool existingIsMed = existing != null &&
      (existing.intervalDays >= 2 ||
          existing.doseCount > 0 ||
          (existing.title?.contains('💊') ?? false));
  ReminderKind kind = existingIsMed
      ? ReminderKind.medication
      : (existing?.location.isNotEmpty ?? false)
          ? ReminderKind.appointment
          : ReminderKind.general;
  final doseCtrl = TextEditingController();
  // دواء: فاصل الأيام بين الجرعات (≥2 ⇒ «كل N يوم») + عدد جرعات الكورس (0 = مستمر).
  int intervalDays = existing?.intervalDays ?? 0;
  int doseCount = existing?.doseCount ?? 0;
  final placeCtrl = TextEditingController();
  final mapLinkCtrl = TextEditingController(text: existing?.location ?? '');
  // مرفق الدعوة (صورة/PDF) للموعد — اختياري.
  String attachmentPath = existing?.attachmentPath ?? '';

  // عند **أول** إنشاء تنبيه جديد: اطلب فكّ كل القيود لضمان عمل المنبّه.
  if (existing == null) {
    await ensureAlarmReliabilityOnce(context);
    if (!context.mounted) return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final scheme = Theme.of(context).colorScheme;
          String two(int n) => n.toString().padLeft(2, '0');
          DateTime combined() => DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
          String repeatLabel(ReminderRepeat r) => switch (r) {
                ReminderRepeat.once => s.t('repeat_once'),
                ReminderRepeat.daily => s.t('repeat_daily'),
                ReminderRepeat.weekly => s.t('repeat_weekly'),
                ReminderRepeat.monthly => s.t('repeat_monthly'),
                ReminderRepeat.yearly => s.t('repeat_yearly'),
              };

          // إعدادات افتراضية ذكية عند اختيار نوع المنبّه.
          void applyKindDefaults(ReminderKind k) {
            // فاصل الأيام/عدد الجرعات خاصّان بالدواء فقط.
            if (k != ReminderKind.medication) {
              intervalDays = 0;
              doseCount = 0;
            }
            switch (k) {
              case ReminderKind.general:
                break;
              case ReminderKind.medication:
                repeat = ReminderRepeat.daily; // الدواء يوميّ غالبًا
                importance = ReminderImportance.critical; // لا يُفوَّت
                preAlerts.clear();
                break;
              case ReminderKind.appointment:
                repeat = ReminderRepeat.once;
                importance = ReminderImportance.high;
                preAlerts
                  ..clear()
                  ..add(60); // تذكير قبل ساعة
                break;
              case ReminderKind.occasion:
                repeat = ReminderRepeat.yearly; // ذكرى سنويّة
                importance = ReminderImportance.medium;
                preAlerts.clear();
                break;
            }
          }

          // يُركّب العنوان النهائي من الاسم + الحقول الخاصّة بالنوع + رمز مميّز.
          String composeTitle() {
            var name = titleCtrl.text.trim();
            if (name.isEmpty) name = kind.label;
            switch (kind) {
              case ReminderKind.medication:
                final d = doseCtrl.text.trim();
                return '${kind.emoji}$name${d.isEmpty ? '' : ' — $d'}';
              case ReminderKind.appointment:
                final pl = placeCtrl.text.trim();
                return '${kind.emoji}$name${pl.isEmpty ? '' : ' @ $pl'}';
              case ReminderKind.occasion:
                return '${kind.emoji}$name';
              case ReminderKind.general:
                return name;
            }
          }

          Widget label(String t) => Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(t,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.bold)),
              );

          // بطاقة منتقي (تاريخ/وقت) صغيرة بحدّ ولمسة بارزة.
          Widget pickerCard(
                  IconData icon, String lbl, String value, VoidCallback onTap) =>
              Expanded(
                child: Material(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  elevation: 1,
                  shadowColor: scheme.shadow.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      child: Row(children: [
                        Icon(icon, size: 20, color: scheme.primary),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(lbl,
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(value,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ]),
                    ),
                  ),
                ),
              );

          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => date = picked);
          }

          Future<void> pickTime() async {
            final picked = await pickTimeWheel(context, time);
            if (picked != null) setState(() => time = picked);
          }
          // التاريخ غير مهمّ عند التكرار اليومي/الأسبوعي (يتكرّر بنفسه)، لكنه مهمّ
          // لكورس الدواء (يحدّد بداية العلاج).
          final medCourse = kind == ReminderKind.medication &&
              (intervalDays >= 2 || doseCount > 0);
          final showDate = medCourse ||
              (repeat != ReminderRepeat.weekly &&
                  repeat != ReminderRepeat.daily);

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // العنوان (ثابت).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                    child: Row(children: [
                      Icon(Icons.add_alarm, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text(existing == null ? 'تنبيه جديد' : 'تعديل التنبيه',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  // المحتوى (قابل للتمرير).
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // نوع المنبّه (فوق العنوان) — يُكيّف الحقول والإعدادات.
                          label('نوع المنبّه'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: ReminderKind.values.map((k) {
                              return ChoiceChip(
                                avatar: Icon(k.icon,
                                    size: 18,
                                    color: kind == k ? scheme.primary : null),
                                label: Text(k.label),
                                selected: kind == k,
                                onSelected: (_) => setState(() {
                                  kind = k;
                                  applyKindDefaults(k);
                                }),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: titleCtrl,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: kind.titleLabel,
                              prefixIcon: Icon(kind.icon),
                            ),
                          ),
                          // حقل خاصّ بالدواء: الجرعة.
                          if (kind == ReminderKind.medication) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: doseCtrl,
                              decoration: const InputDecoration(
                                labelText: 'الجرعة (اختياري)',
                                prefixIcon: Icon(Icons.science_outlined),
                              ),
                            ),
                          ],
                          // حقول خاصّة بالموعد: وصف المكان + رابط خرائط جوجل.
                          if (kind == ReminderKind.appointment) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: placeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'وصف المكان (اختياري)',
                                hintText: 'مثال: مستشفى الملك فهد — بوّابة 3',
                                prefixIcon: Icon(Icons.place_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: mapLinkCtrl,
                              keyboardType: TextInputType.url,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'رابط الموقع (خرائط جوجل)',
                                hintText: 'الصق رابط الموقع هنا',
                                prefixIcon: const Icon(Icons.map_outlined),
                                suffixIcon: IconButton(
                                  tooltip: 'لصق',
                                  icon: const Icon(Icons.content_paste),
                                  onPressed: () async {
                                    final data = await Clipboard.getData(
                                        Clipboard.kTextPlain);
                                    final t = data?.text?.trim() ?? '';
                                    if (t.isNotEmpty) {
                                      setState(() => mapLinkCtrl.text = t);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openExternal(
                                      _mapsSearchUri(placeCtrl.text)),
                                  icon: const Icon(Icons.map),
                                  label: const Text('اختيار من الخريطة'),
                                ),
                              ),
                              if (mapLinkCtrl.text.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'فتح الموقع',
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () {
                                    final u =
                                        Uri.tryParse(mapLinkCtrl.text.trim());
                                    if (u != null) _openExternal(u);
                                  },
                                ),
                              ],
                            ]),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'افتح الخريطة، اختر المكان، انسخ رابط المشاركة، ثم الصقه هنا.',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurface.withOpacity(0.6)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // الدعوة (صورة/PDF) — اختياري.
                            if (attachmentPath.isEmpty)
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final path = await _pickInvitation(context);
                                  if (path != null) {
                                    setState(() => attachmentPath = path);
                                  }
                                },
                                icon: const Icon(Icons.attach_file),
                                label: const Text('إرفاق الدعوة (صورة/PDF)'),
                              )
                            else
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: attachmentPath
                                        .toLowerCase()
                                        .endsWith('.pdf')
                                    ? const Icon(Icons.picture_as_pdf,
                                        color: Colors.red, size: 38)
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(File(attachmentPath),
                                            width: 42,
                                            height: 42,
                                            fit: BoxFit.cover),
                                      ),
                                title: const Text('الدعوة مرفقة'),
                                subtitle: Text(attachmentPath.split('/').last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'فتح',
                                      icon: const Icon(Icons.open_in_new),
                                      onPressed: () => EditorAttachments
                                          .openFile(attachmentPath),
                                    ),
                                    IconButton(
                                      tooltip: 'إزالة',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          setState(() => attachmentPath = ''),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            if (showDate) ...[
                              pickerCard(
                                  Icons.calendar_today,
                                  'التاريخ',
                                  '${date.year}/${two(date.month)}/${two(date.day)}',
                                  pickDate),
                              const SizedBox(width: 10),
                            ],
                            pickerCard(Icons.access_time, 'الوقت',
                                time.format(context), pickTime),
                          ]),
                          const SizedBox(height: 14),
                          // «كل N يوم» للدواء يحجب خيارات التكرار العاديّة.
                          if (!(kind == ReminderKind.medication &&
                              intervalDays >= 2)) ...[
                            label('التكرار'),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: ReminderRepeat.values.map((r) {
                                return ChoiceChip(
                                  label: Text(repeatLabel(r)),
                                  selected: repeat == r,
                                  onSelected: (_) => setState(() => repeat = r),
                                );
                              }).toList(),
                            ),
                            if (repeat == ReminderRepeat.weekly) ...[
                              const SizedBox(height: 14),
                              label('أيام الأسبوع'),
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
                          ],
                          // خيارات خاصّة بالدواء: فاصل الجرعات + مدّة العلاج.
                          if (kind == ReminderKind.medication) ...[
                            const SizedBox(height: 14),
                            label('فاصل الجرعات'),
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              ChoiceChip(
                                label: const Text('حسب التكرار'),
                                selected: intervalDays < 2,
                                onSelected: (_) =>
                                    setState(() => intervalDays = 0),
                              ),
                              ChoiceChip(
                                label: const Text('كل عدّة أيام'),
                                selected: intervalDays >= 2,
                                onSelected: (_) => setState(() =>
                                    intervalDays = intervalDays >= 2
                                        ? intervalDays
                                        : 2),
                              ),
                            ]),
                            if (intervalDays >= 2)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(children: [
                                  const Text('كل'),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline),
                                    onPressed: intervalDays > 2
                                        ? () =>
                                            setState(() => intervalDays--)
                                        : null,
                                  ),
                                  Text('$intervalDays يوم',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: intervalDays < 30
                                        ? () =>
                                            setState(() => intervalDays++)
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text('(${_intervalHint(intervalDays)})',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurface
                                                .withOpacity(0.6))),
                                  ),
                                ]),
                              ),
                            const SizedBox(height: 14),
                            label('مدّة العلاج'),
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              ChoiceChip(
                                label: const Text('مستمر'),
                                selected: doseCount == 0,
                                onSelected: (_) =>
                                    setState(() => doseCount = 0),
                              ),
                              ChoiceChip(
                                label: const Text('عدد جرعات'),
                                selected: doseCount > 0,
                                onSelected: (_) => setState(() =>
                                    doseCount = doseCount > 0 ? doseCount : 10),
                              ),
                            ]),
                            if (doseCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline),
                                    onPressed: doseCount > 1
                                        ? () => setState(() => doseCount--)
                                        : null,
                                  ),
                                  Text('$doseCount جرعة',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: doseCount < 365
                                        ? () => setState(() => doseCount++)
                                        : null,
                                  ),
                                ]),
                              ),
                          ],
                          const SizedBox(height: 14),
                          label(s.t('importance')),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: ReminderImportance.values.map((imp) {
                              return ChoiceChip(
                                avatar: Icon(impIcon(imp),
                                    size: 18, color: impColor(imp)),
                                label: Text(impLabel(s, imp)),
                                selected: importance == imp,
                                onSelected: (_) =>
                                    setState(() => importance = imp),
                              );
                            }).toList(),
                          ),
                          if (repeat == ReminderRepeat.once) ...[
                            const SizedBox(height: 14),
                            label(s.t('pre_alerts')),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final (mins, lbl) in const [
                                  (5, '5د'),
                                  (15, '15د'),
                                  (60, 'ساعة'),
                                  (1440, 'يوم'),
                                ])
                                  FilterChip(
                                    label: Text(lbl),
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
                          const SizedBox(height: 10),
                          label('النغمة'),
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
                            title: Text(settings.alarmTone == 'custom'
                                ? (settings.customToneTitle ?? 'نغمة مخصّصة')
                                : toneName(settings.alarmTone)),
                            trailing: DropdownButton<String>(
                              value: soundCatalog
                                      .any((t) => t.id == settings.alarmTone)
                                  ? settings.alarmTone
                                  : 'custom',
                              isDense: true,
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final t in soundCatalog)
                                  DropdownMenuItem(
                                      value: t.id, child: Text(t.name)),
                                if (settings.alarmTone == 'custom')
                                  DropdownMenuItem(
                                      value: 'custom',
                                      child: Text(
                                          settings.customToneTitle ?? 'مخصّصة 🎵',
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
                          const SizedBox(height: 10),
                          label(s.t('sound_options')),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.volume_up_outlined),
                            title: Text(s.t('auto_raise_volume')),
                            subtitle: Text(s.t('auto_raise_volume_desc'),
                                style: const TextStyle(fontSize: 11.5)),
                            value: settings.autoRaiseVolume,
                            onChanged: (v) async {
                              await settings.setAutoRaiseVolume(v);
                              setState(() {});
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const Icon(Icons.trending_up),
                            title: Text(s.t('gradual_volume')),
                            subtitle: Text(s.t('gradual_volume_desc'),
                                style: const TextStyle(fontSize: 11.5)),
                            value: settings.gradualVolume,
                            onChanged: settings.autoRaiseVolume
                                ? (v) async {
                                    await settings.setGradualVolume(v);
                                    setState(() {});
                                  }
                                : null,
                          ),
                          const SizedBox(height: 10),
                          label('الغفوة'),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.snooze),
                            title: const Text('مدّة الغفوة'),
                            subtitle: Text(settings.snoozeMinutes == 0
                                ? 'بلا غفوة'
                                : '${settings.snoozeMinutes} دقيقة'),
                            trailing: DropdownButton<int>(
                              value: const [0, 5, 10, 15, 30]
                                      .contains(settings.snoozeMinutes)
                                  ? settings.snoozeMinutes
                                  : 10,
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(
                                    value: 0, child: Text('بلا غفوة')),
                                DropdownMenuItem(
                                    value: 5, child: Text('5 دقائق')),
                                DropdownMenuItem(
                                    value: 10, child: Text('10 دقائق')),
                                DropdownMenuItem(
                                    value: 15, child: Text('15 دقيقة')),
                                DropdownMenuItem(
                                    value: 30, child: Text('30 دقيقة')),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                await settings.setSnoozeMinutes(v);
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // شريط الحفظ الثابت (يبقى ظاهرًا دائمًا).
                  Material(
                    elevation: 10,
                    color: scheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        children: [
                          if (existing != null)
                            TextButton.icon(
                              onPressed: () async {
                                if (!await confirmDelete(context,
                                    title: 'حذف التنبيه؟',
                                    message:
                                        'سيُحذف هذا التنبيه ولن يُذكّرك بعد الآن.')) {
                                  return;
                                }
                                await provider.removeReminder(existing);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: Text(s.t('delete')),
                            ),
                          const Spacer(),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(130, 48)),
                            onPressed: () async {
                              final finalTitle = composeTitle();
                              final isMed = kind == ReminderKind.medication;
                              final medInterval = isMed && intervalDays >= 2;
                              // كورس دواء (فاصل/عدد) يمرّ دومًا عبر setStandalone.
                              final isMedCourse =
                                  isMed && (intervalDays >= 2 || doseCount > 0);
                              try {
                                if (repeat == ReminderRepeat.weekly &&
                                    weekdays.isNotEmpty &&
                                    !isMedCourse) {
                                  await provider.setStandaloneWeekly(
                                      finalTitle, time, weekdays,
                                      existing: existing);
                                } else {
                                  await provider.setStandalone(
                                      combined(),
                                      medInterval
                                          ? ReminderRepeat.daily
                                          : repeat,
                                      finalTitle,
                                      importance: importance,
                                      preAlerts: preAlerts.toList()..sort(),
                                      location: mapLinkCtrl.text.trim(),
                                      attachmentPath: attachmentPath,
                                      intervalDays: isMed ? intervalDays : 0,
                                      doseCount: isMed ? doseCount : 0,
                                      existing: existing);
                                }
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                // لا نترك الزر يبدو «لا يعمل»: نُغلق ونُبلّغ.
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '${s.t('save')}: ${s.t('error')}')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check),
                            label: Text(s.t('save')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
