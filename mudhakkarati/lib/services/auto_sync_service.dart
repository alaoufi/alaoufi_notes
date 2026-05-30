import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service.dart';
import 'drive_sync_service.dart';

/// مزامنة تلقائية مع Google Drive: ترفع نسخة مشفّرة عند الإقلاع/الإغلاق إن مرّت
/// مدة كافية منذ آخر رفع، وتستعيد أحدث نسخة عند أول تشغيل على جهاز جديد.
///
/// تعمل فقط بعد تسجيل الدخول إلى Drive وحفظ كلمة مرور المزامنة.
class AutoSyncService {
  AutoSyncService._();
  static final AutoSyncService instance = AutoSyncService._();

  static const _kEnabled = 'autosync_enabled';
  static const _kPassword = 'autosync_password';
  static const _kInterval = 'autosync_interval_min';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<void> setEnabled(bool v, {String? password, int intervalMin = 60}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, v);
    if (password != null && password.isNotEmpty) {
      await prefs.setString(_kPassword, password);
    }
    await prefs.setInt(_kInterval, intervalMin);
  }

  Future<String?> _password() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPassword);
  }

  Future<int> _intervalMin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kInterval) ?? 60;
  }

  /// يرفع نسخة إن مرّت المدة المحددة منذ آخر رفع. يُستدعى عند الإقلاع/الإغلاق.
  /// يعيد true إن رفع فعلًا.
  Future<bool> maybeSync() async {
    if (!await isEnabled()) return false;
    if (!await DriveSyncService.instance.isSignedIn()) return false;
    final pwd = await _password();
    if (pwd == null || pwd.isEmpty) return false;

    final last = await BackupService.instance.lastDriveBackup();
    final interval = Duration(minutes: await _intervalMin());
    if (last != null && DateTime.now().difference(last) < interval) {
      return false; // لم تمضِ المدة بعد.
    }

    try {
      final bytes = await BackupService.instance.buildEncryptedBytes(pwd);
      final ok = await DriveSyncService.instance.upload(bytes);
      if (ok) await BackupService.instance.markDriveBackup();
      return ok;
    } catch (_) {
      return false;
    }
  }
}
