import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/auto_sync_service.dart';
import '../../services/backup_service.dart';
import '../../services/drive_sync_service.dart';
import '../../services/easynotes_import.dart';
import '../home/notes_provider.dart';
import '../reminders/reminders_provider.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _driveEmail;
  bool _autoSync = false;

  @override
  void initState() {
    super.initState();
    _refreshDrive();
  }

  Future<void> _refreshDrive() async {
    final email = await DriveSyncService.instance.currentEmail();
    final auto = await AutoSyncService.instance.isEnabled();
    if (mounted) {
      setState(() {
        _driveEmail = email;
        _autoSync = auto;
      });
    }
  }

  Future<void> _toggleAutoSync(bool v) async {
    if (v) {
      final pwd = await _askPassword('كلمة مرور المزامنة التلقائية');
      if (pwd == null || pwd.isEmpty) return;
      await AutoSyncService.instance.setEnabled(true, password: pwd);
    } else {
      await AutoSyncService.instance.setEnabled(false);
    }
    if (mounted) setState(() => _autoSync = v);
  }

  Future<void> _driveSignIn() async {
    setState(() => _busy = true);
    final ok = await DriveSyncService.instance.signIn();
    setState(() => _busy = false);
    if (ok) {
      await _refreshDrive();
      _toast('تم تسجيل الدخول إلى Google Drive');
    } else {
      _toast('تعذّر تسجيل الدخول');
    }
  }

  Future<void> _driveSignOut() async {
    await DriveSyncService.instance.signOut();
    await _refreshDrive();
    _toast('تم تسجيل الخروج');
  }

  Future<void> _driveUpload() async {
    final pwd = await _askPassword('رفع نسخة إلى Drive');
    if (pwd == null || pwd.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await BackupService.instance.buildEncryptedBytes(pwd);
      final ok = await DriveSyncService.instance.upload(bytes);
      if (ok) await BackupService.instance.markDriveBackup();
      _toast(ok ? 'تم رفع النسخة إلى Drive' : 'فشل الرفع');
    } catch (e) {
      _toast('فشل الرفع: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _driveRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('استعادة من Drive'),
        content: const Text(
            'سيتم استبدال بياناتك الحالية بآخر نسخة على Google Drive. متابعة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استعادة')),
        ],
      ),
    );
    if (confirm != true) return;
    final pwd = await _askPassword('استعادة من Drive');
    if (pwd == null || pwd.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await DriveSyncService.instance.download();
      if (bytes == null) {
        _toast('لا توجد نسخة على Drive');
      } else {
        final res =
            await BackupService.instance.restoreFromBytes(bytes, pwd);
        _toast(res.message);
        if (res.success && mounted) {
          await context.read<NotesProvider>().init();
          await context.read<RemindersProvider>().refresh();
        }
      }
    } catch (e) {
      _toast('فشل الاستعادة: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _askPassword(String title) async {
    final ctrl = TextEditingController();
    final s = S.of(context);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: s.t('backup_password'),
            helperText: s.t('backup_password_hint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(s.t('ok')),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// بطاقة تعرض تاريخ ووقت آخر العمليات (محلي/مشاركة/Drive/استعادة).
  Widget _statusCard(BuildContext context) {
    final bs = BackupService.instance;
    String fmt(DateTime? d) =>
        d == null ? '—' : DateFormat('yyyy/MM/dd  HH:mm').format(d);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 20),
                const SizedBox(width: 8),
                Text('آخر النسخ',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<DateTime?>>(
              future: Future.wait([
                bs.lastLocalBackup(),
                bs.lastShareBackup(),
                bs.lastDriveBackup(),
                bs.lastRestore(),
              ]),
              builder: (context, snap) {
                final d = snap.data ?? const [null, null, null, null];
                Widget row(IconData i, String label, DateTime? t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(i, size: 16, color: Theme.of(context).hintColor),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label)),
                          Text(fmt(t),
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    );
                return Column(
                  children: [
                    row(Icons.save_alt, 'حفظ محلي', d[0]),
                    row(Icons.ios_share, 'مشاركة سحابية', d[1]),
                    row(Icons.add_to_drive, 'رفع إلى Drive', d[2]),
                    row(Icons.restore, 'آخر استعادة', d[3]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    final s = S.of(context);
    final pwd = await _askPassword(s.t('export_backup'));
    if (pwd == null || pwd.isEmpty) return;
    setState(() => _busy = true);
    final result = await BackupService.instance.exportBackup(pwd);
    setState(() => _busy = false);
    _toast(result.message);
  }

  Future<void> _import() async {
    final s = S.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('import_backup')),
        content: Text(s.t('restore_warning')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.t('confirm'))),
        ],
      ),
    );
    if (confirm != true) return;

    final pwd = await _askPassword(s.t('import_backup'));
    if (pwd == null || pwd.isEmpty) return;

    setState(() => _busy = true);
    final result = await BackupService.instance.importBackup(pwd);
    setState(() => _busy = false);
    _toast(result.message);

    if (result.success && mounted) {
      await context.read<NotesProvider>().init();
      await context.read<RemindersProvider>().refresh();
    }
  }

  Future<void> _shareToCloud() async {
    final pwd = await _askPassword('مشاركة إلى السحابة');
    if (pwd == null || pwd.isEmpty) return;
    setState(() => _busy = true);
    final result = await BackupService.instance.shareBackupToCloud(pwd);
    setState(() => _busy = false);
    _toast(result.message);
  }

  Future<void> _importEasyNotes() async {
    final provider = context.read<NotesProvider>();

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    var bytes = picked.files.single.bytes;
    final path = picked.files.single.path;
    if (bytes == null && path != null) {
      bytes = await File(path).readAsBytes();
    }
    if (bytes == null) {
      _toast('تعذّر قراءة الملف.');
      return;
    }

    setState(() => _busy = true);
    final result =
        await EasyNotesImporter(provider.notes, provider.categoriesRepo)
            .importBackup(bytes);
    setState(() => _busy = false);
    _toast(result.message);

    if (result.success && mounted) {
      await provider.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('backup'))),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statusCard(context),
              const SizedBox(height: 8),
              // ===== Google Drive — المزامنة =====
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_sync,
                          color: Color(0xFF1A73E8), size: 32),
                      title: const Text('المزامنة مع Google Drive',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_driveEmail == null
                          ? 'سجّل دخولك مرة واحدة لتُحفظ ملاحظاتك في حسابك تلقائيًا'
                          : '✓ مفعّل لحساب: $_driveEmail'),
                    ),
                    if (_driveEmail == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _driveSignIn,
                            icon: const Icon(Icons.login),
                            label: const Text('تسجيل الدخول بحساب Google'),
                          ),
                        ),
                      )
                    else ...[
                      SwitchListTile(
                        secondary: const Icon(Icons.sync),
                        title: const Text('مزامنة تلقائية'),
                        subtitle: const Text(
                            'تُرفع نسخة محمية تلقائيًا عند فتح التطبيق وإغلاقه'),
                        value: _autoSync,
                        onChanged: _busy ? null : _toggleAutoSync,
                      ),
                      const Divider(height: 1),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _busy ? null : _driveUpload,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('رفع الآن'),
                            ),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _busy ? null : _driveRestore,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('استعادة'),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _driveSignOut,
                            child: const Text('خروج'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text(s.t('export_backup')),
                  subtitle: const Text(
                      'حفظ نسخة مشفّرة من كل ملاحظاتك ومرفقاتك في ملفات الجهاز.'),
                  onTap: _busy ? null : _export,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('مشاركة إلى السحابة'),
                  subtitle: const Text(
                      'إرسال نسخة مشفّرة مباشرة إلى Google Drive أو سحابة هواوي أو أي تطبيق.'),
                  onTap: _busy ? null : _shareToCloud,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(s.t('import_backup')),
                  subtitle: const Text(
                      'استعادة نسخة احتياطية سابقة. سيتم استبدال البيانات الحالية.'),
                  onTap: _busy ? null : _import,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.move_to_inbox),
                  title: const Text('استيراد من Easy Notes'),
                  subtitle: const Text(
                      'اختر ملف النسخة الاحتياطية (.backup) من تطبيق Easy Notes لنقل ملاحظاتك.'),
                  onTap: _busy ? null : _importEasyNotes,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'النسخة الاحتياطية مشفّرة بالكامل (AES-256) وتُحفظ محليًا في جهازك. '
                  'لا يتم رفع أي شيء إلى الإنترنت. احتفظ بكلمة المرور؛ بدونها لا يمكن استعادة النسخة. '
                  'يمكنك نسخ الملف يدويًا إلى Google Drive أو أي مكان لاحقًا إن رغبت.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
