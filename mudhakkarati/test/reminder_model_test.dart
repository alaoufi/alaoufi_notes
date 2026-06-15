import 'package:flutter_test/flutter_test.dart';
import 'package:mudhakkarati/data/models/enums.dart';
import 'package:mudhakkarati/data/models/reminder.dart';

void main() {
  group('Reminder serialization roundtrip', () {
    test('preserves all fields through toMap/fromMap', () {
      final r = Reminder(
        id: 7,
        noteId: 3,
        title: 'دواء',
        time: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        repeat: ReminderRepeat.weekly,
        isActive: true,
        importance: ReminderImportance.critical,
        preAlerts: const [5, 15, 60, 1440],
        notificationId: 12345,
      );
      final back = Reminder.fromMap(r.toMap());
      expect(back.noteId, 3);
      expect(back.title, 'دواء');
      expect(back.repeat, ReminderRepeat.weekly);
      expect(back.importance, ReminderImportance.critical);
      expect(back.preAlerts, [5, 15, 60, 1440]);
      expect(back.notificationId, 12345);
      expect(back.time.millisecondsSinceEpoch, 1700000000000);
    });

    test('importance unknown value falls back to high', () {
      expect(ReminderImportanceX.fromDb('garbage'), ReminderImportance.high);
      expect(ReminderImportanceX.fromDb(null), ReminderImportance.high);
      expect(ReminderImportanceX.fromDb('low'), ReminderImportance.low);
    });

    test('pre_alerts parsing ignores empty/garbage/<=0', () {
      Reminder fromPre(String s) => Reminder.fromMap({
            'note_id': 1,
            'title': 't',
            'time': 0,
            'repeat': 'once',
            'is_active': 1,
            'notification_id': 1,
            'importance': 'high',
            'pre_alerts': s,
          });
      expect(fromPre('').preAlerts, isEmpty);
      expect(fromPre(',,').preAlerts, isEmpty);
      expect(fromPre('0,5,-3,15,x').preAlerts, [5, 15]);
    });
  });

  group('Notification ID block scheme', () {
    const stride = 1 << 26;
    const slots = [0, 1, 2, 3, 4, 10, 11, 12, 13];
    test('no 32-bit overflow at max base', () {
      const base = 1 << 26;
      final maxId = base + 13 * stride;
      expect(maxId < (1 << 31) - 1, isTrue);
    });
    test('blocks are internally unique for many bases', () {
      for (var base = 1; base < (1 << 26); base += 97777) {
        final ids = slots.map((k) => base + k * stride).toSet();
        expect(ids.length, slots.length);
      }
    });
  });
}
