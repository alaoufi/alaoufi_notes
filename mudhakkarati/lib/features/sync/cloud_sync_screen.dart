import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/sync/sync_service.dart';
import '../../widgets/ui_kit.dart';
import '../home/notes_provider.dart';

/// شاشة المزامنة السحابية: WebDAV (متاح) و Google Drive (قريبًا).
///
/// مزامنة حقيقية ثنائية الاتجاه بدمج «آخر تعديل يفوز» لكل ملاحظة، وكل ما يُرفع
/// **مشفّر طرفيًّا** بعبارة مرور يحدّدها المستخدم.
class CloudSyncScreen extends StatefulWidget {
  /// [embedded] = يُعرض داخل تبويب (بلا Scaffold/شريط علوي خاص).
  final bool embedded;
  const CloudSyncScreen({super.key, this.embedded = false});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _phrase = TextEditingController();

  SyncProvider _provider = SyncProvider.webdav;
  bool _auto = false;
  bool _busy = false;
  DateTime? _last;
  bool _loaded = false;
  String? _googleEmail; // بريد حساب Google المتّصل (إن وُجد)

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = SyncService.instance;
    final prov = await s.provider();
    final cfg = await s.webdavConfig();
    final auto = await s.autoSync();
    final last = await s.lastSync();
    setState(() {
      _provider = prov == SyncProvider.none ? SyncProvider.webdav : prov;
      _url.text = cfg.url;
      _user.text = cfg.user;
      _auto = auto;
      _last = last;
      _loaded = true;
    });
    // حدّث حالة اتصال Google في الخلفية (دخول صامت).
    final email = await SyncService.instance.googleEmail();
    if (mounted) setState(() => _googleEmail = email);
  }

  Future<void> _googleConnect() async {
    setState(() => _busy = true);
    try {
      final email = await SyncService.instance.googleConnect();
      if (mounted) {
        setState(() {
          _googleEmail = email;
          if (email != null) _provider = SyncProvider.googleDrive;
        });
      }
      _snack(email != null
          ? 'تم الاتصال: $email'
          : 'تعذّر تسجيل الدخول — تأكّد من إعداد Google (انظر الملاحظة بالأسفل)');
    } catch (e) {
      _snack('فشل تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleDisconnect() async {
    await SyncService.instance.googleDisconnect();
    if (mounted) setState(() => _googleEmail = null);
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _phrase.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// وقت نسبيّ ودّي لآخر مزامنة (الآن/قبل دقائق/ساعات/أيام).
  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
    return 'قبل ${diff.inDays ~/ 30} شهر';
  }

  Future<bool> _saveSettings() async {
    final s = SyncService.instance;
    if (_phrase.text.trim().isEmpty && !await s.hasPassphrase()) {
      _snack('أدخل عبارة مرور التشفير (نفسها على كل الأجهزة)');
      return false;
    }
    if (_provider == SyncProvider.webdav) {
      if (_url.text.trim().isEmpty || _user.text.trim().isEmpty) {
        _snack('أدخل رابط الخادم واسم المستخدم');
        return false;
      }
      await s.setProvider(SyncProvider.webdav);
      await s.setWebdavConfig(
        url: _url.text,
        user: _user.text,
        password: _pass.text,
      );
    } else if (_provider == SyncProvider.googleDrive) {
      if (_googleEmail == null) {
        _snack('سجّل الدخول بحساب Google أولًا');
        return false;
      }
      await s.setProvider(SyncProvider.googleDrive);
    }
    if (_phrase.text.trim().isNotEmpty) {
      await s.setPassphrase(_phrase.text.trim());
    }
    await s.setAutoSync(_auto);
    return true;
  }

  Future<void> _test() async {
    if (!await _saveSettings()) return;
    setState(() => _busy = true);
    final r = await SyncService.instance.testConnection();
    setState(() => _busy = false);
    _snack(r.message);
  }

  Future<void> _syncNow() async {
    if (!await _saveSettings()) return;
    setState(() => _busy = true);
    final r = await SyncService.instance.syncNow();
    if (r.ok && mounted) {
      // أعِد تحميل الملاحظات والتصنيفات بعد الدمج.
      final notes = context.read<NotesProvider>();
      await notes.loadCategories();
      await notes.refresh();
      _last = await SyncService.instance.lastSync();
    }
    setState(() => _busy = false);
    _snack(r.message);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = !_loaded
        ? const Center(child: CircularProgressIndicator())
        : _content(context, scheme);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: gradientAppBar(context, 'المزامنة السحابية'),
      body: body,
    );
  }

  Widget _content(BuildContext context, ColorScheme scheme) {
    return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // اختيار المزوّد.
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.cloud_sync, color: scheme.primary),
                        const SizedBox(width: 10),
                        const Text('مزوّد المزامنة',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                      const SizedBox(height: 10),
                      SegmentedButton<SyncProvider>(
                        segments: const [
                          ButtonSegment(
                              value: SyncProvider.webdav,
                              icon: Icon(Icons.dns_outlined),
                              label: Text('WebDAV')),
                          ButtonSegment(
                              value: SyncProvider.googleDrive,
                              icon: Icon(Icons.add_to_drive_outlined),
                              label: Text('Google Drive')),
                        ],
                        selected: {_provider},
                        onSelectionChanged: (sel) =>
                            setState(() => _provider = sel.first),
                      ),
                    ],
                  ),
                ),

                // إعداد WebDAV.
                if (_provider == SyncProvider.webdav)
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('بيانات خادم WebDAV',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                            'مثال Nextcloud: https://cloud.example.com/remote.php/dav/files/USER/Notes',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'رابط المجلّد',
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _user,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pass,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور (أو كلمة مرور التطبيق)',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ],
                    ),
                  ),

                // إعداد Google Drive.
                if (_provider == SyncProvider.googleDrive)
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('حساب Google',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                            'تُحفظ النسخة في مجلّد التطبيق المخفي بحسابك (لا تظهر بين ملفاتك).',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        if (_googleEmail != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.account_circle,
                                color: Colors.green),
                            title: Text(_googleEmail!),
                            subtitle: const Text('متّصل'),
                            trailing: TextButton.icon(
                              onPressed: _busy ? null : _googleDisconnect,
                              icon: const Icon(Icons.logout),
                              label: const Text('خروج'),
                            ),
                          )
                        else
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _googleConnect,
                            icon: const Icon(Icons.login),
                            label: const Text('تسجيل الدخول بحساب Google'),
                          ),
                      ],
                    ),
                  ),

                // عبارة مرور التشفير الطرفي.
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.shield_outlined, color: scheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('عبارة مرور التشفير (E2E)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          'تُشفّر بها ملاحظاتك قبل رفعها — الخادم لا يقرؤها. استخدم نفس العبارة على كل أجهزتك.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phrase,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'عبارة المرور (اتركها فارغة للإبقاء عليها)',
                          prefixIcon: Icon(Icons.key),
                        ),
                      ),
                    ],
                  ),
                ),

                // المزامنة التلقائية + آخر مزامنة.
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _auto,
                        onChanged: (v) => setState(() => _auto = v),
                        secondary: const Icon(Icons.sync),
                        title: const Text('مزامنة تلقائية عند فتح التطبيق',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ListTile(
                        leading: Icon(
                            _last != null ? Icons.cloud_done : Icons.cloud_off,
                            color: _last != null
                                ? Colors.green
                                : Theme.of(context).hintColor),
                        title: const Text('آخر مزامنة'),
                        subtitle: Text(_last == null
                            ? 'لم تتم بعد'
                            : '${_relative(_last!)} • ${DateFormat('yyyy/MM/dd – HH:mm').format(_last!)}'),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _test,
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text('اختبار الاتصال'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _syncNow,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.cloud_sync),
                          label: const Text('زامن الآن'),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'ملاحظة: في هذه النسخة تُزامَن الملاحظات النصّية وقوائم المهام '
                    'والوسوم والتصنيفات. المرفقات (صور/صوت/ملفات) تُحفظ عبر النسخة '
                    'الاحتياطية الكاملة.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
  }
}
