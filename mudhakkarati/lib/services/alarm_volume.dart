import 'package:flutter/services.dart';

/// رفع/استعادة مستوى صوت **تيّار المنبّه** (STREAM_ALARM) أصليًّا — يعمل حتى
/// عندما يكون الجهاز على الصامت أو الصوت منخفض. يُستخدم عند ظهور شاشة المنبّه.
class AlarmVolume {
  AlarmVolume._();
  static const _ch = MethodChannel('com.mudhakkarati.app/alarm_volume');

  /// يرفع صوت المنبّه إلى [targetPercent]٪ — فورًا أو بالتدرّج خلال
  /// [rampSeconds] ثانية (0 = فوري). يحفظ المستوى الأصليّ تلقائيًّا.
  static Future<void> raise({int targetPercent = 100, int rampSeconds = 0}) async {
    try {
      await _ch.invokeMethod('raise', {
        'targetPercent': targetPercent,
        'rampSeconds': rampSeconds,
      });
    } catch (_) {/* غير مدعوم/ممنوع — نتجاهل */}
  }

  /// يستعيد مستوى صوت المنبّه الأصليّ.
  static Future<void> restore() async {
    try {
      await _ch.invokeMethod('restore');
    } catch (_) {}
  }
}
