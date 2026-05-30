import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database/app_database.dart';
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
      final fileName = 'mudhakkarati_$stamp.$_ext';

      final tmpDir = await getTemporaryDirectory();
      final tmpPath = p.join(tmpDir.path, fileName);
      await File(tmpPath).writeAsBytes(encrypted, flush: true);

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ النسخة الاحتياطية',
        fileName: fileName,
        bytes: encrypted,
      );

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
      final fileName = 'mudhakkarati_$stamp.$_ext';
      final tmpDir = await getTemporaryDirectory();
      final tmpPath = p.join(tmpDir.path, fileName);
      await File(tmpPath).writeAsBytes(encrypted, flush: true);

      await SharePlus.instance.share(ShareParams(
        files: [XFile(tmpPath, mimeType: 'application/octet-stream')],
        text: 'نسخة Alaoufi Notes الاحتياطية المشفّرة',
        subject: fileName,
      ));
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

      for (final file in archive) {
        if (!file.isFile) continue;
        final data = file.content as List<int>;
        if (file.name == 'database.db') {
          await File(dbPath).writeAsBytes(data, flush: true);
        } else if (file.name.startsWith('attachments/')) {
          final dest = p.join(attDir.path, p.basename(file.name));
          await File(dest).writeAsBytes(data, flush: true);
        }
      }

      // إعادة فتح قاعدة البيانات بالبيانات المستعادة.
      await AppDatabase.instance.reopen();

      return const BackupResult(true, 'تمت الاستعادة بنجاح');
    } catch (e) {
      return BackupResult(false, 'فشل الاستيراد: $e');
    }
  }
}
