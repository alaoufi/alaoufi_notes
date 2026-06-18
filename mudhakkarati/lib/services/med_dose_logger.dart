import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/med_dose.dart';
import '../data/models/reminder.dart';
import '../data/repositories/med_repository.dart';
import '../data/repositories/reminder_repository.dart';

/// يُسجّل جرعة في «سجلّ الأدوية» تلقائيًّا عن كل **موعد** لمنبّه دواء (العنوان
/// يحمل الرمز 💊) منذ آخر فحص. الهدف: معرفة **كم جرعة** ومتى — لا «أُخذت/فاتت».
///
/// لماذا «عند الفتح» لا لحظة الرنين؟ لأن أندرويد لا يتيح لـFlutter تشغيل كود
/// موثوق عند **ظهور** الإشعار والتطبيق مغلق. لذا نعوّض بحساب كل المواعيد الفائتة
/// منذ آخر مرّة وتسجيلها دفعةً عند فتح التطبيق/شاشة الأدوية — فلا تضيع أي جرعة.
class MedDoseLogger {
  MedDoseLogger._();
  static final instance = MedDoseLogger._();

  static const _prefix = 'med_logged_until_';

  Future<void> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminders =
          await ReminderRepository(AppDatabase.instance).getAll();
      final medRepo = MedRepository(AppDatabase.instance);
      final now = DateTime.now();

      for (final r in reminders) {
        if (!r.isActive || r.id == null) continue;
        final title = r.title ?? '';
        if (!title.contains('💊')) continue; // ليس منبّه دواء.

        final key = '$_prefix${r.id}';
        final lastMs = prefs.getInt(key);
        if (lastMs == null) {
          // أوّل مرّة نرى هذا المنبّه: نبدأ العدّ من الآن (لا نُسجّل الماضي).
          await prefs.setInt(key, now.millisecondsSinceEpoch);
          continue;
        }

        final after = DateTime.fromMillisecondsSinceEpoch(lastMs);
        final occ = occurrencesBetween(r.repeat, r.time, after, now);
        if (occ.isNotEmpty) {
          final parsed = parseMedTitle(title);
          for (final o in occ) {
            await medRepo.insert(MedDose(
                name: parsed.$1, dose: parsed.$2, taken: true, at: o));
          }
        }
        await prefs.setInt(key, now.millisecondsSinceEpoch);
      }
    } catch (_) {
      // لا يجب أن تُعطّل بدء التطبيق.
    }
  }

  /// اسم الدواء وجرعته من عنوان المنبّه «💊 الاسم — الجرعة».
  @visibleForTesting
  static (String, String?) parseMedTitle(String title) {
    var t = title.replaceAll('💊', '').trim();
    String? dose;
    final idx = t.indexOf(' — ');
    if (idx >= 0) {
      final d = t.substring(idx + 3).trim();
      if (d.isNotEmpty) dose = d;
      t = t.substring(0, idx).trim();
    }
    return (t.isEmpty ? 'دواء' : t, dose);
  }

  /// مواعيد منبّه بتكرار [repeat] وزمن أساس [base] الواقعة بعد [after] وحتى
  /// [until] (شاملة [until]). محدودة بسقف أمان لتفادي أي حلقة طويلة.
  @visibleForTesting
  static List<DateTime> occurrencesBetween(
      ReminderRepeat repeat, DateTime base, DateTime after, DateTime until) {
    final res = <DateTime>[];
    if (repeat == ReminderRepeat.once) {
      if (base.isAfter(after) && !base.isAfter(until)) res.add(base);
      return res;
    }
    DateTime t;
    switch (repeat) {
      case ReminderRepeat.daily:
        t = DateTime(after.year, after.month, after.day, base.hour, base.minute);
        while (!t.isAfter(after)) {
          t = t.add(const Duration(days: 1));
        }
        while (!t.isAfter(until) && res.length < 400) {
          res.add(t);
          t = t.add(const Duration(days: 1));
        }
        break;
      case ReminderRepeat.weekly:
        t = DateTime(after.year, after.month, after.day, base.hour, base.minute);
        while (t.weekday != base.weekday || !t.isAfter(after)) {
          t = t.add(const Duration(days: 1));
        }
        while (!t.isAfter(until) && res.length < 200) {
          res.add(t);
          t = t.add(const Duration(days: 7));
        }
        break;
      case ReminderRepeat.monthly:
        t = DateTime(after.year, after.month, base.day, base.hour, base.minute);
        while (!t.isAfter(after)) {
          t = DateTime(t.year, t.month + 1, base.day, base.hour, base.minute);
        }
        while (!t.isAfter(until) && res.length < 60) {
          res.add(t);
          t = DateTime(t.year, t.month + 1, base.day, base.hour, base.minute);
        }
        break;
      case ReminderRepeat.yearly:
        t = DateTime(after.year, base.month, base.day, base.hour, base.minute);
        while (!t.isAfter(after)) {
          t = DateTime(t.year + 1, base.month, base.day, base.hour, base.minute);
        }
        while (!t.isAfter(until) && res.length < 20) {
          res.add(t);
          t = DateTime(t.year + 1, base.month, base.day, base.hour, base.minute);
        }
        break;
      case ReminderRepeat.once:
        break;
    }
    return res;
  }
}
