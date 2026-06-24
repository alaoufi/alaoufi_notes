import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/enums.dart';
import '../data/models/note.dart';
import '../features/editor/rich_text_field.dart';
import '../features/editor/share_image_screen.dart';
import '../features/home/notes_provider.dart';
import '../features/links/note_links.dart';
import '../features/reminders/reminder_dialog.dart';
import '../features/security/pin_setup.dart';
import '../features/settings/settings_provider.dart';
import '../services/notification_service.dart';
import '../services/pdf_export_service.dart';
import 'color_picker_sheet.dart';
import 'confirm_dialog.dart';

/// شيت إجراءات الملاحظة (عند الضغط المطوّل أو من المحرر).
///
/// [onDetails] (من المحرّر) يضيف عنصر «تفاصيل» يفتح العنوان والتاريخ والحذف.
Future<void> showNoteActions(BuildContext context, Note note,
    {VoidCallback? onDetails, VoidCallback? onSelect, VoidCallback? onStats}) async {
  final s = S.of(context);
  final provider = context.read<NotesProvider>();
  final settings = context.read<SettingsProvider>();

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      Widget tile(IconData icon, String label, VoidCallback onTap,
          {Color? color}) {
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          onTap: onTap,
        );
      }

      // قابل للتمرير ومحدود الارتفاع كي يظهر كل العناصر (ومنها «حذف») دائمًا.
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            child: Wrap(
              children: [
            if (onSelect != null) ...[
              tile(Icons.checklist_rtl, s.t('select_multiple'), () {
                Navigator.pop(context);
                onSelect();
              }),
              const Divider(height: 1),
            ],
            if (onDetails != null) ...[
              tile(Icons.info_outline, 'تفاصيل (العنوان والتاريخ)', () {
                Navigator.pop(context);
                onDetails();
              }),
              const Divider(height: 1),
            ],
            if (onStats != null) ...[
              tile(Icons.bar_chart, s.t('stats'), () {
                Navigator.pop(context);
                onStats();
              }),
              const Divider(height: 1),
            ],
            tile(
              note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              note.isPinned ? s.t('unpin') : s.t('pin'),
              () async {
                Navigator.pop(context);
                await provider.togglePin(note);
              },
            ),
            tile(
              note.isFavorite ? Icons.star : Icons.star_border,
              note.isFavorite ? s.t('unfavorite') : s.t('favorite'),
              () async {
                Navigator.pop(context);
                await provider.toggleFavorite(note);
              },
              color: note.isFavorite ? Colors.amber.shade700 : null,
            ),
            tile(Icons.palette_outlined, s.t('color'), () async {
              Navigator.pop(context);
              final res = await showColorPicker(context, note.color,
                  currentStyle: note.bgStyle,
                  currentGradient: note.gradient,
                  currentOnLine: note.ruleOnLine ?? settings.ruleOnLine,
                  currentThickness:
                      note.ruleThickness ?? settings.ruleThickness,
                  currentOpacity: note.ruleOpacity ?? settings.ruleOpacity,
                  currentLineHeight:
                      note.ruleLineHeight ?? settings.noteLineHeight);
              if (res != null) {
                await provider.saveNote(note.copyWith(
                  color: res.value,
                  clearColor: res.value == null,
                  bgStyle: res.bgStyle,
                  gradient: res.gradient,
                  clearGradient: res.gradient == null,
                  ruleOnLine: res.ruleOnLine,
                  ruleThickness: res.ruleThickness,
                  ruleOpacity: res.ruleOpacity,
                  ruleLineHeight: res.ruleLineHeight,
                ));
              }
            }),
            tile(Icons.alarm, s.t('reminder'), () async {
              Navigator.pop(context);
              await showReminderDialog(context, note);
            }),
            tile(
              note.isLocked ? Icons.lock_open : Icons.lock_outline,
              note.isLocked ? s.t('unlock') : s.t('lock'),
              () async {
                Navigator.pop(context);
                if (!note.isLocked) {
                  // قبل قفل ملاحظة لأول مرة، تأكد من وجود رقم سري.
                  final ok = await ensurePinConfigured(context);
                  if (!ok) return;
                }
                await provider.setLocked(note, !note.isLocked);
              },
            ),
            tile(Icons.link, 'الروابط [[ ]]', () async {
              Navigator.pop(context);
              await showNoteLinks(context, note);
            }),
            tile(Icons.copy_all, s.t('duplicate'), () async {
              Navigator.pop(context);
              await provider.duplicate(note);
            }),
            tile(Icons.content_copy, s.t('copy'), () async {
              Navigator.pop(context);
              await Clipboard.setData(
                  ClipboardData(text: _asText(note)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.t('copied'))));
              }
            }),
            tile(Icons.share, s.t('share'), () async {
              Navigator.pop(context);
              await SharePlus.instance.share(ShareParams(text: _asText(note)));
            }),
            tile(Icons.chat, 'إرسال عبر واتساب', () async {
              await _sendWhatsApp(context, note);
            }, color: const Color(0xFF25D366)),
            tile(Icons.image_outlined, s.t('share_image'), () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ShareImageScreen(note: note)),
              );
            }),
            tile(Icons.picture_as_pdf_outlined, 'تصدير PDF', () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(const SnackBar(
                  content: Text('جارٍ تجهيز ملف PDF…'),
                  duration: Duration(seconds: 1)));
              try {
                await PdfExportService.exportNote(note);
              } catch (e) {
                messenger.showSnackBar(
                    SnackBar(content: Text('تعذّر التصدير: $e')));
              }
            }),
            tile(
              note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              note.isArchived ? s.t('unarchive') : s.t('archive'),
              () async {
                Navigator.pop(context);
                await provider.setArchived(note, !note.isArchived);
              },
            ),
            const Divider(height: 1),
            // حذف واضح بأسفل القائمة (أحمر) مع رسالة تأكيد.
            tile(Icons.delete_outline, s.t('delete'), () async {
              final ok = await confirmDeleteNote(context);
              if (!ok) return;
              // نحذف قبل إغلاق الشيت كي يكتشف المحرّر الحذف بشكل موثوق.
              await provider.moveToTrash(note);
              if (context.mounted) Navigator.pop(context);
            }, color: Theme.of(context).colorScheme.error),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// إرسال محتوى الملاحظة عبر واتساب لمستلمٍ يختاره المستخدم — فورًا أو مجدولًا.
/// ميزة مستقلّة عن المنبّه/التذكير. لا تُرسِل تلقائيًّا (واتساب يمنع ذلك): تُفتح
/// المحادثة والرسالة جاهزة وتضغط أنت «إرسال». المجدول: في وقته تظهر بطاقة، تضغطها
/// فيفتح واتساب جاهزًا.
Future<void> _sendWhatsApp(BuildContext context, Note note) async {
  final messenger = ScaffoldMessenger.of(context); // ثابت (مستوى التطبيق)
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getString('wa_last_number') ?? '';
  final ctrl = TextEditingController(text: last);
  if (!context.mounted) return;
  // النتيجة: ('now'|'schedule', الرقم) أو null عند الإلغاء.
  final res = await showDialog<(String, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إرسال عبر واتساب'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'أدخل رقم المستلم مع رمز الدولة (مثال: 9665XXXXXXXX). تُفتح المحادثة '
              'والرسالة جاهزة، وتضغط أنت «إرسال».',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '9665XXXXXXXX',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        TextButton.icon(
          onPressed: () => Navigator.pop(ctx, ('schedule', ctrl.text)),
          icon: const Icon(Icons.schedule),
          label: const Text('جدولة'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, ('now', ctrl.text)),
          icon: const Icon(Icons.chat),
          label: const Text('الآن'),
        ),
      ],
    ),
  );
  if (res == null) return;
  final (action, raw) = res;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('أدخل رقمًا صحيحًا')));
    return;
  }
  await prefs.setString('wa_last_number', digits);
  final text = _asText(note);

  if (action == 'now') {
    if (context.mounted) Navigator.pop(context); // أغلق الشيت
    final uri =
        Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return;
  }

  // جدولة: اختر التاريخ والوقت (الشيت ما زال مفتوحًا لتوفير سياق صالح).
  if (!context.mounted) return;
  final when = await _pickFutureDateTime(context);
  if (context.mounted) Navigator.pop(context); // أغلق الشيت بعد الاختيار
  if (when == null) {
    messenger.showSnackBar(
        const SnackBar(content: Text('أُلغيت الجدولة (اختر وقتًا في المستقبل)')));
    return;
  }
  final id = DateTime.now().microsecondsSinceEpoch.remainder(0x7fffffff);
  await NotificationService.instance
      .scheduleWhatsApp(id: id, when: when, digits: digits, text: text);
  final hh = when.hour.toString().padLeft(2, '0');
  final mm = when.minute.toString().padLeft(2, '0');
  messenger.showSnackBar(SnackBar(
      content: Text(
          'مُجدوَل ${when.year}/${when.month}/${when.day} $hh:$mm — في وقته تفتح واتساب بالرسالة جاهزة')));
}

/// منتقي تاريخ + وقت في المستقبل (يعيد null عند الإلغاء أو وقت ماضٍ).
Future<DateTime?> _pickFutureDateTime(BuildContext context) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
  );
  if (t == null) return null;
  final when = DateTime(date.year, date.month, date.day, t.hour, t.minute);
  return when.isAfter(DateTime.now()) ? when : null;
}

/// رسالة تحذير قبل الحذف. تعيد true إن أكّد المستخدم.
Future<bool> confirmDeleteNote(BuildContext context) {
  return confirmDelete(
    context,
    title: 'حذف الملاحظة؟',
    message: 'ستُنقل إلى المهملات ويمكنك استرجاعها منها لاحقًا.',
  );
}

/// نص النسخ/المشاركة: العنوان + المحتوى فقط — بدون التاريخ أو التصنيف.
/// لملاحظات النص الغني نحوّل Delta إلى نص صريح ليُنسخ نظيفًا.
String _asText(Note note) {
  final buffer = StringBuffer();
  if (note.title.trim().isNotEmpty) buffer.writeln(note.title);

  final body = note.type == NoteType.text
      ? richToPlainText(note.content)
      : note.content;
  if (body.trim().isNotEmpty) buffer.writeln(body);

  return buffer.toString().trim();
}
