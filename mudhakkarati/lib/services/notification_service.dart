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

  /// مدّة الغفوة بالدقائق (0 = بلا غفوة). تُضبط من الإعدادات.
  int snoozeMinutes = 10;

  /// «وضع عدم النسيان» للتذكيرات الحرجة: يُعاد التنبيه تلقائيًّا حتى التأكيد.
  /// عدد مرّات الإعادة والفاصل بينها (يُضبطان لاحقًا من الإعدادات).
  int forgetRepeats = 4;
  Duration forgetInterval = const Duration(minutes: 3);
  static const int _forgetStride = 1 << 26; // فصل معرّفات الإعادات

  /// يُلغي تذكيرًا مع كل الإشعارات التابعة (إعادات «عدم النسيان» + التنبيهات
  /// المسبقة) ضمن كتلة معرّفاته.
  Future<void> _cancelFollowups(int baseId) async {
    for (var k = 1; k <= 15; k++) {
      await _plugin.cancel(baseId + k * _forgetStride);
    }
  }

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

    // قناة هادئة للتذكيرات منخفضة الأهمية (بلا صوت).
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'alaoufi_quiet',
        'تنبيهات هادئة',
        description: 'إشعارات بلا صوت',
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
      ),
    );

    _initialized = true;
  }

  /// النغمات المتاحة (أسماء ملفات raw). نغمات طبيعية ناعمة مولّدة أصليًّا
  /// (خالية من حقوق النشر). مرتّبة ضمن تصنيفات في «مكتبة الأصوات».
  static const alarmTones = [
    // بحر
    'ocean', 'gentle_waves', 'sea_shore', 'blue_harbour', 'water',
    // غابة
    'forest', 'rainforest', 'creek', 'birds',
    // مطر
    'rain', 'rain_window', 'soft_storm',
    // رياح
    'desert_wind', 'evening_breeze',
    // هادئة
    'aurora', 'morning_light', 'soft_bell', 'chime', 'bell',
    // منبّهات
    'alarm', 'digital_alarm', 'urgent', 'wake_bell',
  ];

  /// النغمة المختارة حاليًا (افتراضي ocean = Ocean Whisper) — تُضبط من الإعدادات.
  /// قد تكون 'custom' عند اختيار نغمة من ملفات/نغمات الجهاز.
  String _tone = 'ocean';
  String get tone => _tone;
  set tone(String t) {
    if (alarmTones.contains(t) || t == 'custom') _tone = t;
  }

  // ===== نغمة مخصّصة من الجهاز (رابط URI يقرأه نظام الإشعارات) =====
  String? _customUri;
  String _customChannelId = 'alaoufi_alarm_custom_0';

  /// يضبط نغمة مخصّصة من الجهاز ويُنشئ قناة جديدة لها (قنوات أندرويد لا
  /// يمكن تغيير صوتها بعد الإنشاء، لذا نُنشئ قناة بمعرّف جديد عند كل تغيير).
  Future<void> setCustomTone(String? uri, {int seq = 0}) async {
    _customUri = uri;
    if (uri == null || uri.isEmpty) return;
    _tone = 'custom';
    _customChannelId = 'alaoufi_alarm_custom_$seq';
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // حذف القنوات المخصّصة السابقة (تنظيف) قبل إنشاء الجديدة.
    for (var i = seq - 1; i >= 0 && i >= seq - 3; i--) {
      await androidImpl?.deleteNotificationChannel('alaoufi_alarm_custom_$i');
    }
    await androidImpl?.createNotificationChannel(
      AndroidNotificationChannel(
        _customChannelId,
        'المنبّه (نغمة مخصّصة)',
        description: 'تنبيهات بنغمة مختارة من الجهاز',
        importance: Importance.max,
        playSound: true,
        sound: UriAndroidNotificationSound(uri),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
      ),
    );
  }

  Future<void> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  /// تفاصيل الإشعار حسب **مستوى الأهمية**:
  /// - low: إشعار هادئ بلا صوت/اهتزاز (قناة منفصلة).
  /// - medium: صوت فقط.
  /// - high: صوت + اهتزاز.
  /// - critical: شاشة كاملة + إصرار (تكرار الصوت) حتى تفاعل المستخدم.
  AndroidNotificationDetails _alarmDetails(ReminderImportance imp) {
    if (imp == ReminderImportance.low) {
      return const AndroidNotificationDetails(
        'alaoufi_quiet',
        'تنبيهات هادئة',
        channelDescription: 'إشعارات بلا صوت',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
      );
    }
    final isCustom = _tone == 'custom' && _customUri != null;
    final critical = imp == ReminderImportance.critical;
    final vibrate = imp == ReminderImportance.high || critical;
    return AndroidNotificationDetails(
      isCustom ? _customChannelId : 'alaoufi_alarm_$_tone',
      isCustom ? 'المنبّه (نغمة مخصّصة)' : 'المنبّه ($_tone)',
      channelDescription: 'تنبيهات المنبّه والتذكيرات',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      // شاشة كاملة للتذكيرات الحرجة فقط.
      fullScreenIntent: critical,
      playSound: true,
      sound: isCustom
          ? UriAndroidNotificationSound(_customUri!)
          : RawResourceAndroidNotificationSound(_tone),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: vibrate,
      vibrationPattern:
          vibrate ? Int64List.fromList([0, 600, 300, 600, 300, 600]) : null,
      // FLAG_INSISTENT (تكرار الصوت حتى التفاعل) للحرجة فقط.
      additionalFlags: critical ? Int32List.fromList([4]) : null,
      actions: [
        if (snoozeMinutes > 0)
          AndroidNotificationAction(_snoozeAction, 'غفوة',
              showsUserInterface: false, cancelNotification: true),
        const AndroidNotificationAction(_dismissAction, 'إيقاف',
            showsUserInterface: false, cancelNotification: true),
      ],
    );
  }

  NotificationDetails _detailsFor(ReminderImportance imp) =>
      NotificationDetails(android: _alarmDetails(imp));

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
      _detailsFor(reminder.importance),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: match,
      payload: 'note:${reminder.noteId}|title:$safeTitle|body:$safeBody'
          '|imp:${reminder.importance.dbValue}|base:${reminder.notificationId}',
    );

    // «وضع عدم النسيان»: للتذكيرات الحرجة لمرّة واحدة، أعِد التنبيه تلقائيًّا
    // عند فواصل متتالية حتى يؤكّد المستخدم (الإلغاء يحذف كل الإعادات).
    final base = reminder.notificationId;
    if (reminder.importance == ReminderImportance.critical &&
        reminder.repeat == ReminderRepeat.once &&
        base < _forgetStride &&
        forgetRepeats > 0) {
      for (var k = 1; k <= forgetRepeats; k++) {
        final when = scheduled.add(forgetInterval * k);
        await _plugin.zonedSchedule(
          base + k * _forgetStride,
          safeTitle,
          '$safeBody ⏰',
          when,
          _detailsFor(ReminderImportance.critical),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'note:${reminder.noteId}|title:$safeTitle|body:$safeBody'
              '|imp:critical|base:$base',
        );
      }
    }

    // تنبيهات مسبقة قبل الموعد (للتذكيرات لمرّة واحدة): إشعار متوسّط لكل فارق.
    if (reminder.repeat == ReminderRepeat.once &&
        reminder.preAlerts.isNotEmpty &&
        base < _forgetStride) {
      final now = tz.TZDateTime.now(tz.local);
      var i = 0;
      for (final mins in reminder.preAlerts.take(4)) {
        final when = scheduled.subtract(Duration(minutes: mins));
        if (when.isAfter(now)) {
          await _plugin.zonedSchedule(
            base + (10 + i) * _forgetStride,
            '⏳ ${_beforeLabel(mins)} • ${title.trim().isEmpty ? "تذكير" : title.trim()}',
            safeBody,
            when,
            _detailsFor(ReminderImportance.medium),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'note:${reminder.noteId}|title:$safeTitle|body:$safeBody'
                '|imp:medium|base:$base',
          );
        }
        i++;
      }
    }
  }

  String _beforeLabel(int mins) {
    if (mins % 1440 == 0) return 'قبل ${mins ~/ 1440} يوم';
    if (mins % 60 == 0) return 'قبل ${mins ~/ 60} ساعة';
    return 'قبل $mins دقيقة';
  }

  /// يعالج الضغط على التذكير أو أزراره (إيقاف/غفوة/فتح الملاحظة).
  Future<void> handleAction(NotificationResponse r,
      {bool fromBackground = false}) async {
    final payload = r.payload ?? '';
    final noteId = _extractInt(payload, 'note:');

    // «تم الإنجاز/إيقاف» أو غفوة ⇒ أكّد الاستلام: ألغِ كل إعادات «عدم النسيان».
    final base = _extractInt(payload, 'base:') ?? r.id ?? 0;

    switch (r.actionId) {
      case _dismissAction:
        await init();
        await _plugin.cancel(base);
        await _cancelFollowups(base); // أوقف إعادة التنبيه نهائيًّا
        return;
      case _snoozeAction:
        await init();
        await _plugin.cancel(base);
        await _cancelFollowups(base); // أوقف الإعادات ثم أجِّل
        await _scheduleSnooze(base, payload);
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
    final imp = ReminderImportanceX.fromDb(_extractStr(payload, 'imp:'));
    final when = tz.TZDateTime.now(tz.local)
        .add(Duration(minutes: snoozeMinutes > 0 ? snoozeMinutes : 10));
    await _plugin.zonedSchedule(
      id, // نفس المعرّف.
      title,
      body,
      when,
      _detailsFor(imp),
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
    // ألغِ أي إعادات «عدم النسيان» تابعة (إن وُجدت).
    await _cancelFollowups(notificationId);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
