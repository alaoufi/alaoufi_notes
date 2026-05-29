import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/enums.dart';
import '../data/models/reminder.dart';

/// خدمة الإشعارات المحلية (تذكيرات بدون إنترنت).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'mudhakkarati_reminders';
  static const _channelName = 'التذكيرات';

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // في حال تعذّر تحديد المنطقة الزمنية بالاسم، نستخدم الافتراضي.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'تنبيهات تذكيرات الملاحظات',
        importance: Importance.max,
      ),
    );

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'تنبيهات تذكيرات الملاحظات',
          importance: Importance.max,
          priority: Priority.high,
          // تنبيه متكرر حتى يؤكده المستخدم.
          fullScreenIntent: true,
          category: AndroidNotificationCategory.reminder,
        ),
      );

  /// جدولة تذكير. يدعم التكرار يومي/أسبوعي/شهري/سنوي/مرة واحدة.
  Future<void> schedule(Reminder reminder, String title, String body) async {
    await init();
    final scheduled = tz.TZDateTime.from(reminder.time, tz.local);

    final safeTitle = title.trim().isEmpty ? 'تذكير' : title.trim();
    final safeBody = body.trim().isEmpty ? 'لديك تذكير من مذكراتي' : body.trim();

    DateTimeComponents? match;
    switch (reminder.repeat) {
      case ReminderRepeat.once:
        match = null;
        break;
      case ReminderRepeat.daily:
        match = DateTimeComponents.time;
        break;
      case ReminderRepeat.weekly:
        match = DateTimeComponents.dayOfWeekAndTime;
        break;
      case ReminderRepeat.monthly:
        match = DateTimeComponents.dayOfMonthAndTime;
        break;
      case ReminderRepeat.yearly:
        match = DateTimeComponents.dateAndTime;
        break;
    }

    await _plugin.zonedSchedule(
      reminder.notificationId,
      safeTitle,
      safeBody,
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: match,
      payload: 'note:${reminder.noteId}',
    );
  }

  Future<void> cancel(int notificationId) async {
    await init();
    await _plugin.cancel(notificationId);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
