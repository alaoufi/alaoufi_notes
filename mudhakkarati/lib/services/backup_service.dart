import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import '../data/database/db_key.dart';
import 'encryption_service.dart';
import 'file_service.dart';

/// نتيجة عملية النسخ الاحتياطي.
class BackupResult {
  final bool success;
  final String message;
  final String? filePath;
  const BackupResult(this.success, this.message, {this.filePath});
}

/// إنشاء/استعادة نسخة احتياطية محلية مشفّرة.
///
/// النسخة عبارة عن ملف ZIP (قاعدة البيانات + كل المرفقات) مشفّر بـ AES-256،
/// يُحفظ في ملفات الجهاز التي يختارها المستخدم. تعمل بالكامل دون إنترنت.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _ext = 'mdkbak';

  // مفاتيح حفظ وقت آخر عملية لكل وجهة.
  static const _kLastLocal = 'last_backup_local';
  static const _kLastShare = 'last_backup_share';
  static const _kLastRestore = 'last_restore';

  // ---- إعدادات النسخ الاحتياطي التلقائي ----
  static const _kAutoEnabled = 'auto_backup_enabled';
  static const _kAutoIntervalDays = 'auto_backup_interval_days';
  static const _kAutoKeep = 'auto_backup_keep';
  static const _kLastAuto = 'last_auto_backup';
  // كلمة مرور النسخ التلقائي تُحفظ في التخزين الآمن (Keystore) حتى تعمل
  // النسخة دون تدخّل المستخدم.
  static const _kAutoPwd = 'auto_backup_password';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> _stamp(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }

  Future<DateTime?> _readStamp(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<DateTime?> lastLocalBackup() => _readStamp(_kLastLocal);
  Future<DateTime?> lastShareBackup() => _readStamp(_kLastShare);
  Future<DateTime?> lastRestore() => _readStamp(_kLastRestore);
  Future<DateTime?> lastAutoBackup() => _readStamp(_kLastAuto);

  // ---- قراءة/ضبط إعدادات النسخ التلقائي ----

  Future<bool> autoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoEnabled) ?? false;
  }

  /// الفاصل الزمني بين النسخ التلقائية بالأيام (1 = يومي، 7 = أسبوعي).
  Future<int> autoBackupIntervalDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kAutoIntervalDays) ?? 1;
  }

  /// عدد النسخ التلقائية المحفوظة قبل حذف الأقدم.
  Future<int> autoBackupKeep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kAutoKeep) ?? 5;
  }

  Future<void> setAutoBackupEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoEnabled, v);
  }

  Future<void> setAutoBackupIntervalDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoIntervalDays, days);
  }

  Future<void> setAutoBackupKeep(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoKeep, n);
  }

  Future<void> setAutoBackupPassword(String password) async {
    await _secure.write(key: _kAutoPwd, value: password);
  }

  Future<bool> hasAutoBackupPassword() async {
    final v = await _secure.read(key: _kAutoPwd);
    return v != null && v.isNotEmpty;
  }

  /// مجلّد النسخ التلقائية داخل بيانات التطبيق الخاصة.
  Future<Directory> autoBackupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'auto_backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// قائمة ملفات النسخ التلقائية (الأحدث أولًا — الاسم يحمل طابعًا زمنيًا).
  Future<List<File>> listAutoBackups() async {
    final dir = await autoBackupDir();
    if (!await dir.exists()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.$_ext'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// تفعيل النسخة اليومية التلقائية بضغطة واحدة: يضبط الفترة يومًا، ويولّد كلمة
  /// مرور عشوائية تُحفظ بأمان (تُستخدم تلقائيًا عند الاستعادة الداخلية)، ثم ينشئ
  /// نسخة فورًا. لا يحتاج المستخدم لإدخال أي شيء.
  Future<void> enableDailyAutoBackup() async {
    await setAutoBackupIntervalDays(1);
    if (!await hasAutoBackupPassword()) {
      final rnd = Random.secure();
      final pwd = List.generate(
              24, (_) => rnd.nextInt(36).toRadixString(36))
          .join();
      await setAutoBackupPassword(pwd);
    }
    await setAutoBackupEnabled(true);
    await runAutoBackup(); // نسخة فورية أولى.
  }

  /// أحدث نسخة تلقائية محفوظة (أو null إن لم توجد).
  Future<File?> latestAutoBackup() async {
    final files = await listAutoBackups(); // الأحدث أولًا
    return files.isEmpty ? null : files.first;
  }

  /// ينشئ نسخة تلقائية الآن ويحفظها في المجلّد الداخلي مع تدوير الأقدم.
  Future<BackupResult> runAutoBackup() async {
    try {
      final pwd = await _secure.read(key: _kAutoPwd);
      if (pwd == null || pwd.isEmpty) {
        return const BackupResult(false, 'لم تُضبط كلمة مرور النسخ التلقائي');
      }
      final encrypted = await _buildEncrypted(pwd);
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final dir = await autoBackupDir();
      final file = File(p.join(dir.path, 'auto_$stamp.$_ext'));
      await file.writeAsBytes(encrypted, flush: true);
      await _rotateAutoBackups();
      await _stamp(_kLastAuto);
      return BackupResult(true, 'تم إنشاء نسخة تلقائية', filePath: file.path);
    } catch (e) {
      return BackupResult(false, 'فشل النسخ التلقائي: $e');
    }
  }

  /// يحذف النسخ التلقائية الأقدم مُبقيًا على آخر [autoBackupKeep] نسخة.
  Future<void> _rotateAutoBackups() async {
    final keep = await autoBackupKeep();
    final files = await listAutoBackups(); // الأحدث أولًا
    if (files.length <= keep) return;
    for (final f in files.sublist(keep)) {
      try {
        await f.delete();
      } catch (_) {/* تجاهل */}
    }
  }

  /// يُستدعى عند إقلاع التطبيق: ينفّذ نسخة تلقائية إن حان موعدها فقط.
  Future<void> maybeRunAutoBackup() async {
    if (!await autoBackupEnabled()) return;
    if (!await hasAutoBackupPassword()) return;
    final last = await lastAutoBackup();
    if (last != null) {
      final intervalDays = await autoBackupIntervalDays();
      final due = last.add(Duration(days: intervalDays));
      if (DateTime.now().isBefore(due)) return; // لم يحن الموعد بعد
    }
    await runAutoBackup();
  }

  /// استعادة من نسخة تلقائية محدّدة (مسار داخلي) بكلمة مرور النسخ التلقائي.
  Future<BackupResult> restoreAutoBackup(File file) async {
    try {
      final pwd = await _secure.read(key: _kAutoPwd);
      if (pwd == null || pwd.isEmpty) {
        return const BackupResult(false, 'لا توجد كلمة مرور للنسخ التلقائي');
      }
      final encrypted = await file.readAsBytes();
      return _restoreFromBytes(encrypted, pwd);
    } catch (e) {
      return BackupResult(false, 'فشل الاستعادة: $e');
    }
  }

  /// إنشاء نسخة احتياطية مشفّرة وحفظها عبر منتقي الملفات.
  Future<BackupResult> exportBackup(String password) async {
    try {
      final archive = Archive();

      // 1) قاعدة البيانات.
      final dbPath = await AppDatabase.instance.path;
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final bytes = await dbFile.readAsBytes();
        archive.addFile(ArchiveFile('database.db', bytes.length, bytes));
      }

      // 1ب) مفتاح تشفير القاعدة (محميّ أصلًا بكلمة مرور النسخة) — ليعمل
      // فكّ التشفير عند الاستعادة على أي جهاز.
      final key = await DbKeyManager.instance.getOrCreateKey();
      final keyBytes = utf8.encode(key);
      archive.addFile(ArchiveFile('dbkey.txt', keyBytes.length, keyBytes));

      // 2) كل المرفقات.
      final attDir = await FileService.instance.attachmentsDir();
      if (await attDir.exists()) {
        for (final entity in attDir.listSync()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final name = 'attachments/${p.basename(entity.path)}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }

      final zipped = ZipEncoder().encode(archive);
      if (zipped == null) {
        return const BackupResult(false, 'تعذّر إنشاء الأرشيف');
      }

      // 3) التشفير.
      final encrypted = EncryptionService.instance
          .encryptBytes(Uint8List.fromList(zipped), password);

      // 4) الحفظ: نكتب أولًا في الملفات المؤقتة ثم نتيح حفظه للمستخدم.
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'Notes_$stamp.$_ext';

      final tmpDir = await getTemporaryDirectory();
      final tmpPath = p.join(tmpDir.path, fileName);
      await File(tmpPath).writeAsBytes(encrypted, flush: true);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: fileName,
        bytes: encrypted,
      );

      await _stamp(_kLastLocal);
      return BackupResult(
        true,
        'تم إنشاء النسخة الاحتياطية',
        filePath: savedPath ?? tmpPath,
      );
    } catch (e) {
      return BackupResult(false, 'فشل التصدير: $e');
    }
  }

  /// إنشاء نسخة مشفّرة ومشاركتها مباشرة إلى أي تطبيق سحابي
  /// (Google Drive / سحابة هواوي / Telegram / البريد...) بضغطة واحدة.
  Future<BackupResult> shareBackupToCloud(String password) async {
    try {
      final encrypted = await _buildEncrypted(password);
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'Notes_$stamp.$_ext';
      final tmpDir = await getTemporaryDirectory();
      final tmpPath = p.join(tmpDir.path, fileName);
      await File(tmpPath).writeAsBytes(encrypted, flush: true);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(tmpPath, mimeType: 'application/octet-stream')],
        text: 'نسخة Alaoufi Notes الاحتياطية المشفّرة',
        subject: fileName,
      ));
      await _stamp(_kLastShare);
      return BackupResult(true, 'تمت مشاركة النسخة', filePath: tmpPath);
    } catch (e) {
      return BackupResult(false, 'فشل المشاركة: $e');
    }
  }

  /// يبني أرشيف (قاعدة بيانات + مرفقات) مشفّرًا بكلمة المرور.
  Future<Uint8List> _buildEncrypted(String password) async {
    final archive = Archive();
    final dbPath = await AppDatabase.instance.path;
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final bytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('database.db', bytes.length, bytes));
    }
    final key = await DbKeyManager.instance.getOrCreateKey();
    final keyBytes = utf8.encode(key);
    archive.addFile(ArchiveFile('dbkey.txt', keyBytes.length, keyBytes));
    final attDir = await FileService.instance.attachmentsDir();
    if (await attDir.exists()) {
      for (final entity in attDir.listSync()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(
              'attachments/${p.basename(entity.path)}', bytes.length, bytes));
        }
      }
    }
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null) throw Exception('تعذّر إنشاء الأرشيف');
    return EncryptionService.instance
        .encryptBytes(Uint8List.fromList(zipped), password);
  }

  /// استعادة نسخة احتياطية من ملف يختاره المستخدم.
  Future<BackupResult> importBackup(String password) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية',
        type: FileType.any,
      );
      if (picked == null || picked.files.isEmpty) {
        return const BackupResult(false, 'لم يتم اختيار ملف');
      }

      final path = picked.files.single.path;
      if (path == null) {
        return const BackupResult(false, 'تعذّر قراءة الملف');
      }

      final encrypted = await File(path).readAsBytes();
      return _restoreFromBytes(encrypted, password);
    } catch (e) {
      return BackupResult(false, 'فشل الاستيراد: $e');
    }
  }

  /// المنطق المشترك لاستعادة نسخة مشفّرة من بايتاتها (يستخدمه الاستيراد اليدوي
  /// والاستعادة من النسخ التلقائية).
  Future<BackupResult> _restoreFromBytes(
      Uint8List encrypted, String password) async {
    late Uint8List zipped;
    try {
      zipped = EncryptionService.instance.decryptBytes(encrypted, password);
    } catch (_) {
      return const BackupResult(false, 'كلمة المرور خاطئة أو الملف تالف');
    }

    final archive = ZipDecoder().decodeBytes(zipped);

    // استبدال قاعدة البيانات.
    final dbPath = await AppDatabase.instance.path;
    final attDir = await FileService.instance.attachmentsDir();

    // تنظيف المرفقات القديمة.
    if (await attDir.exists()) {
      for (final e in attDir.listSync()) {
        if (e is File) await e.delete();
      }
    }

    String? restoredKey;
    for (final file in archive) {
      if (!file.isFile) continue;
      final data = file.content as List<int>;
      if (file.name == 'database.db') {
        await File(dbPath).writeAsBytes(data, flush: true);
      } else if (file.name == 'dbkey.txt') {
        restoredKey = utf8.decode(data);
      } else if (file.name.startsWith('attachments/')) {
        final dest = p.join(attDir.path, p.basename(file.name));
        await File(dest).writeAsBytes(data, flush: true);
      }
    }

    // ضبط مفتاح التشفير ليطابق القاعدة المستعادة.
    if (restoredKey != null && restoredKey.isNotEmpty) {
      // نسخة مشفّرة: استخدم مفتاحها وتجاوز الترحيل.
      await DbKeyManager.instance.setKey(restoredKey);
      await DbKeyManager.instance.markMigrated();
    } else {
      // نسخة قديمة (غير مشفّرة): أعد الترحيل لتشفيرها بمفتاح هذا الجهاز.
      await DbKeyManager.instance.clearMigrated();
    }

    // إعادة فتح قاعدة البيانات بالبيانات المستعادة.
    await AppDatabase.instance.reopen();

    await _stamp(_kLastRestore);
    return const BackupResult(true, 'تمت الاستعادة بنجاح');
  }
}
