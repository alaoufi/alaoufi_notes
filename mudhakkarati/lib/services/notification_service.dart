import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/enums.dart';
import '../data/models/reminder.dart';

/// مفتاح تنقّل عام لفتح الملاحظة عند الضغط على التذكير.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// يُستدعى عند الضغط على «غفوة» من الخلفية (لا بد أن يكون دالة عليا).
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  // إعادة الجدولة من الخلفية تتم عبر معالج عام بسيط.
  NotificationService.instance.handleAction(response, fromBackground: true);
}

/// خدمة الإشعارات/المنبّه المحلي (بدون إنترنت).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // قناة المنبّه (صوت إنذار متواصل + اهتزاز + أهمية قصوى).

  static const _snoozeAction = 'snooze';
  static const _dismissAction = 'dismiss';

  /// مدّة الغفوة بالدقائق.
  static const snoozeMinutes = 10;

  /// يُستدعى عند فتح ملاحظة من التذكير (يضبطه التطبيق).
  void Function(int noteId)? onOpenNote;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {}

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (r) => handleAction(r),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // قناة لكل نغمة (أندرويد يربط الصوت بالقناة).
    for (final tone in alarmTones) {
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          'alaoufi_alarm_$tone',
          'المنبّه ($tone)',
          description: 'تنبيهات المنبّه والتذكيرات',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(tone),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
        ),
      );
    }

    _initialized = true;
  }

  /// النغمات المتاحة (أسماء ملفات raw).
  static const alarmTones = ['alarm', 'chime', 'bell'];

  /// النغمة المختارة حاليًا (افتراضي alarm) — تُضبط من الإعدادات.
  String _tone = 'alarm';
  String get tone => _tone;
  set tone(String t) {
    if (alarmTones.contains(t)) _tone = t;
  }

  Future<void> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  AndroidNotificationDetails get _alarmDetails => AndroidNotificationDetails(
        'alaoufi_alarm_$_tone',
        'المنبّه ($_tone)',
        channelDescription: 'تنبيهات المنبّه والتذكيرات',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_tone),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 600, 300, 600, 300, 600]),
        // FLAG_INSISTENT: يُكرّر الصوت حتى يوقفه المستخدم.
        additionalFlags: Int32List.fromList([4]),
        actions: const [
          AndroidNotificationAction(_snoozeAction, 'غفوة',
              showsUserInterface: false, cancelNotification: true),
          AndroidNotificationAction(_dismissAction, 'إيقاف',
              showsUserInterface: false, cancelNotification: true),
        ],
      );

  NotificationDetails get _details =>
      NotificationDetails(android: _alarmDetails);

  /// جدولة تذكير. يدعم التكرار يومي/أسبوعي/شهري/سنوي/مرة واحدة.
  Future<void> schedule(Reminder reminder, String title, String body) async {
    await init();
    final scheduled = tz.TZDateTime.from(reminder.time, tz.local);

    final safeTitle = title.trim().isEmpty ? '⏰ تذكير' : '⏰ ${title.trim()}';
    final safeBody =
        body.trim().isEmpty ? 'لديك تذكير من Alaoufi Notes' : body.trim();

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
      payload: 'note:${reminder.noteId}|title:$safeTitle|body:$safeBody',
    );
  }

  /// يعالج الضغط على التذكير أو أزراره (إيقاف/غفوة/فتح الملاحظة).
  Future<void> handleAction(NotificationResponse r,
      {bool fromBackground = false}) async {
    final payload = r.payload ?? '';
    final noteId = _extractInt(payload, 'note:');

    switch (r.actionId) {
      case _dismissAction:
        return; // أُلغي الإشعار تلقائيًا.
      case _snoozeAction:
        await _scheduleSnooze(r.id ?? 0, payload);
        return;
      default:
        // ضغط على جسم الإشعار → افتح الملاحظة.
        if (noteId != null) {
          if (onOpenNote != null) {
            onOpenNote!(noteId);
          }
        }
    }
  }

  Future<void> _scheduleSnooze(int id, String payload) async {
    await init();
    final title = _extractStr(payload, 'title:') ?? '⏰ تذكير';
    final body = _extractStr(payload, 'body:') ?? 'تذكير مؤجَّل';
    final when = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: snoozeMinutes));
    await _plugin.zonedSchedule(
      id, // نفس المعرّف.
      title,
      body,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  int? _extractInt(String payload, String key) {
    final v = _extractStr(payload, key);
    return v == null ? null : int.tryParse(v);
  }

  String? _extractStr(String payload, String key) {
    for (final part in payload.split('|')) {
      if (part.startsWith(key)) return part.substring(key.length);
    }
    return null;
  }

  /// التذكير الذي فُتح به التطبيق (إن أُقلع بالضغط على إشعار).
  Future<int?> initialNoteId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final payload = details!.notificationResponse?.payload ?? '';
      return _extractInt(payload, 'note:');
    }
    return null;
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
