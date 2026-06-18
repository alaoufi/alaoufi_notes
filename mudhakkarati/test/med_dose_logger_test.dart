import 'package:flutter_test/flutter_test.dart';
import 'package:mudhakkarati/data/models/enums.dart';
import 'package:mudhakkarati/services/med_dose_logger.dart';

/// حارس منطق تسجيل جرعات الأدوية تلقائيًّا من منبّهات 💊.
void main() {
  group('parseMedTitle', () {
    test('اسم + جرعة', () {
      final r = MedDoseLogger.parseMedTitle('💊 فيتامين د — حبة');
      expect(r.$1, 'فيتامين د');
      expect(r.$2, 'حبة');
    });
    test('اسم بلا جرعة', () {
      final r = MedDoseLogger.parseMedTitle('💊 فيتامين د');
      expect(r.$1, 'فيتامين د');
      expect(r.$2, isNull);
    });
  });

  group('occurrencesBetween', () {
    test('مرّة واحدة داخل/خارج المدى', () {
      final base = DateTime(2026, 1, 2, 8, 0);
      expect(
          MedDoseLogger.occurrencesBetween(ReminderRepeat.once, base,
              DateTime(2026, 1, 1), DateTime(2026, 1, 3)),
          [base]);
      expect(
          MedDoseLogger.occurrencesBetween(ReminderRepeat.once, base,
              DateTime(2026, 1, 5), DateTime(2026, 1, 9)),
          isEmpty);
    });

    test('يوميّ: جرعة لكل يوم في المدى', () {
      final occ = MedDoseLogger.occurrencesBetween(
        ReminderRepeat.daily,
        DateTime(2026, 1, 1, 8, 0),
        DateTime(2026, 1, 1, 0, 0),
        DateTime(2026, 1, 4, 12, 0),
      );
      expect(occ.length, 4); // 1،2،3،4 يناير
      expect(occ.every((d) => d.hour == 8 && d.minute == 0), isTrue);
    });

    test('أسبوعيّ: نفس يوم الأسبوع وبفاصل 7 أيام', () {
      final base = DateTime(2026, 1, 6, 9, 0); // يوم أساس
      final occ = MedDoseLogger.occurrencesBetween(
        ReminderRepeat.weekly,
        base,
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 31),
      );
      expect(occ, isNotEmpty);
      expect(occ.every((d) => d.weekday == base.weekday), isTrue);
      for (var i = 1; i < occ.length; i++) {
        expect(occ[i].difference(occ[i - 1]).inDays, 7);
      }
    });

    test('لا تكرارات إذا لم يمضِ موعد جديد', () {
      final base = DateTime(2026, 1, 1, 8, 0);
      final t = DateTime(2026, 1, 10, 12, 0);
      expect(
          MedDoseLogger.occurrencesBetween(
              ReminderRepeat.daily, base, t, t.add(const Duration(minutes: 1))),
          isEmpty);
    });
  });
}
