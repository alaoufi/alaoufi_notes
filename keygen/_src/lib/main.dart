import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'license_codec.dart';

void main() => runApp(const KeygenApp());

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
// مفتاح تخزين قديم (مذكراتي) — نهاجر منه إن وُجد.
const _kLegacySeed = 'owner_seed_hex';

/// تعريف تطبيق في المولّد.
/// - [prefix]: بادئة الصيغة الموقَّعة (يجب أن تطابق التطبيق).
/// - [pubB64]: المفتاح العامّ — للتحقّق أنّ البذرة المُدخَلة صحيحة وللعرض.
/// - [embeddedSeedHex]: بذرة مدمجة (مراح)؛ null ⇒ بذرة المالك تُدخَل وتُخزَّن.
class AppDef {
  final String id;
  final String name;
  final String prefix;
  final String pubB64;
  final String? embeddedSeedHex;
  const AppDef(this.id, this.name, this.prefix, this.pubB64,
      [this.embeddedSeedHex]);
}

// بذرة «مراح» مدمجة في أداة المالك فقط (ليست في التطبيق المنشور).
const _marahSeedHex =
    '38beeb3667847dc80f248da1960f0bd7ac6484afa048ff641978119991a4d470';

// بذرة المفتاح العالميّ (master) — لأيّ تطبيق يضع مفتاحه العامّ وبادئة UNIV1.
const _universalSeedHex =
    '21200553e66913ea203a7b6f9a8d52a3e09fda7e76cd58353e66b750f79b2de9';

// قائمة التطبيقات المتاحة في المولّد. أضِف تطبيقًا جديدًا بإضافة سطر هنا.
// «عام» أوّلًا (الافتراضي): مفتاح واحد يصلح لأيّ تطبيق يتبع القاعدة (UNIV1).
const List<AppDef> _appDefs = [
  AppDef('universal', 'عام — أيّ تطبيق', 'UNIV1',
      '0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=', _universalSeedHex),
  // مذكراتي تحوّل إلى المفتاح العالميّ (UNIV1) — بذرته مدمجة، فيعمل الخيار مباشرةً
  // بلا لصق مفتاح (المفتاح الخاصّ القديم MDKL1 فُقد ولم يَعُد مستخدَمًا).
  AppDef('mudhakkarati', 'مذكراتي', 'UNIV1',
      '0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=', _universalSeedHex),
  AppDef('marah', 'مراح', 'MRHL1',
      'q6t0BfdSs/AF9EAHkRAwAoaqRwHFp7m052uCRxlwKw4=', _marahSeedHex),
];

class KeygenApp extends StatelessWidget {
  const KeygenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مولّد أكواد التفعيل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3949AB),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const _GeneratorScreen(),
    );
  }
}

class _GeneratorScreen extends StatefulWidget {
  const _GeneratorScreen();

  @override
  State<_GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<_GeneratorScreen> {
  final _deviceCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '30');
  bool _permanent = false;
  String? _key;
  AppDef _app = _appDefs.first;

  static const _presets = [7, 30, 90, 180, 365];

  @override
  void dispose() {
    _deviceCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  // ---- حلّ البذرة للتطبيق المختار ----

  /// يعيد بذرة التطبيق: مدمجة (مراح)، أو مخزّنة، أو يطلبها من المالك (ويتحقّق
  /// أنّها تطابق المفتاح العامّ ثم يحفظها). يعيد null عند الإلغاء.
  Future<List<int>?> _seedFor(AppDef app) async {
    if (app.embeddedSeedHex != null) return _hexToBytes(app.embeddedSeedHex!);

    // مخزّنة لهذا التطبيق؟
    String? stored = await _storage.read(key: 'seed_${app.id}');
    // هجرة من المفتاح القديم (مذكراتي فقط).
    if ((stored == null || stored.length != 64) && app.id == 'mudhakkarati') {
      final legacy = await _storage.read(key: _kLegacySeed);
      if (legacy != null && legacy.length == 64) {
        await _storage.write(key: 'seed_${app.id}', value: legacy);
        stored = legacy;
      }
    }
    if (stored != null && stored.length == 64) return _hexToBytes(stored);

    if (!mounted) return null;
    final hex = await _promptSeed(app);
    if (hex == null) return null;
    await _storage.write(key: 'seed_${app.id}', value: hex);
    return _hexToBytes(hex);
  }

  /// حوار إدخال المفتاح الخاصّ لتطبيق ما، مع التحقّق أنّه يطابق مفتاحه العامّ.
  Future<String?> _promptSeed(AppDef app) async {
    final ctrl = TextEditingController();
    String? err;
    var busy = false;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('مفتاح «${app.name}» الخاصّ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'ألصق المفتاح الخاصّ (Seed — 64 خانة hex) الخاصّ بـ«${app.name}». '
                  'يُحفظ على هذا الجهاز ويُتحقّق أنّه يطابق التطبيق.',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'المفتاح الخاصّ (64 خانة)',
                  border: const OutlineInputBorder(),
                  errorText: err,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final hex = ctrl.text
                          .trim()
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^0-9a-f]'), '');
                      if (hex.length != 64) {
                        setLocal(() => err = 'المفتاح يجب أن يكون 64 خانة hex');
                        return;
                      }
                      setLocal(() {
                        busy = true;
                        err = null;
                      });
                      final pub =
                          await LicenseCodec.publicKeyB64(_hexToBytes(hex));
                      if (pub != app.pubB64) {
                        setLocal(() {
                          busy = false;
                          err = 'لا يطابق «${app.name}» (مفتاح خاطئ)';
                        });
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx, hex);
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- التوليد ----

  Future<void> _generate() async {
    final device = _deviceCtrl.text.trim();
    if (device.isEmpty) {
      _snack('أدخل رقم الجهاز أولًا');
      return;
    }
    var days = 0;
    if (!_permanent) {
      days = int.tryParse(_daysCtrl.text.trim()) ?? 0;
      if (days <= 0) {
        _snack('أدخل عدد أيام صحيح');
        return;
      }
    }
    final seed = await _seedFor(_app);
    if (seed == null) return; // أُلغي إدخال البذرة.
    final key = await LicenseCodec.generate(
      deviceId: device,
      durationDays: _permanent ? 0 : days,
      seed: seed,
      prefix: _app.prefix,
    );
    if (!mounted) return;
    setState(() => _key = key);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مولّد أكواد التفعيل'),
        actions: [
          IconButton(
            tooltip: 'معلومات المفتاح',
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // اختيار التطبيق المراد إنشاء مفتاح له.
            DropdownButtonFormField<AppDef>(
              initialValue: _app,
              decoration: const InputDecoration(
                labelText: 'التطبيق',
                prefixIcon: Icon(Icons.apps),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final a in _appDefs)
                  DropdownMenuItem(
                    value: a,
                    child: Text('${a.name}  (${a.prefix})'),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _app = v;
                  _key = null; // ألغِ رمزًا سابقًا لتطبيق آخر.
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceCtrl,
              decoration: const InputDecoration(
                labelText: 'رقم الجهاز',
                hintText: 'ألصق رقم الجهاز من التطبيق',
                prefixIcon: Icon(Icons.smartphone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: _permanent,
              onChanged: (v) => setState(() => _permanent = v),
              title: const Text('ترخيص دائم'),
              subtitle: const Text('بلا انتهاء صلاحية'),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_permanent) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد الأيام',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in _presets)
                    ActionChip(
                      label: Text('$p يوم'),
                      onPressed: () => setState(() => _daysCtrl.text = '$p'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.vpn_key),
              label: Text('توليد كود لـ «${_app.name}»'),
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            if (_key != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('رمز تفعيل «${_app.name}»',
                        style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SelectableText(
                      _key!,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _key!));
                        _snack('تم نسخ الكود');
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ الكود'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInfo() {
    final embedded = _app.embeddedSeedHex != null;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('«${_app.name}» — المفتاح العامّ',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
                'يجب أن يطابق المفتاح العامّ المدمج في ذلك التطبيق، وإلا لن '
                'تُقبل الأكواد.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            _CopyBox(label: 'Public Key', value: _app.pubB64),
            if (embedded) ...[
              const SizedBox(height: 12),
              const Text('بذرة هذا التطبيق مدمجة في المولّد (جاهزة).',
                  style: TextStyle(fontSize: 12, color: Colors.green)),
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _storage.delete(key: 'seed_${_app.id}');
                  if (_app.id == 'mudhakkarati') {
                    await _storage.delete(key: _kLegacySeed);
                  }
                  if (mounted) _snack('حُذف مفتاح «${_app.name}» — سيُطلب عند التوليد القادم');
                },
                icon: const Icon(Icons.key_off),
                label: Text('حذف/تغيير مفتاح «${_app.name}»'),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _showNewKeyPair();
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('توليد زوج مفاتيح لتطبيق جديد'),
            ),
          ],
        ),
      ),
    );
  }

  /// يولّد زوج مفاتيح جديدًا (لتطبيق جديد) ويعرضه للنسخ. لا يمسّ التطبيقات الحالية.
  Future<void> _showNewKeyPair() async {
    final kp = await LicenseCodec.newKeyPair();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زوج مفاتيح جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('للمفتاح الخاصّ (Seed) — احفظه سرًّا:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _CopyBox(label: 'Private Seed (hex)', value: kp.seedHex),
              const SizedBox(height: 12),
              const Text('المفتاح العامّ — ضعه في التطبيق الجديد:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _CopyBox(label: 'Public Key', value: kp.publicKeyB64),
              const SizedBox(height: 10),
              const Text(
                  '⚠️ فقدان المفتاح الخاصّ = عدم القدرة على توليد أكواد لهذا التطبيق.',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('تمام')),
        ],
      ),
    );
  }
}

class _CopyBox extends StatelessWidget {
  final String label;
  final String value;
  const _CopyBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم نسخ $label')));
            },
          ),
        ],
      ),
    );
  }
}

List<int> _hexToBytes(String hex) => [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16)
    ];
