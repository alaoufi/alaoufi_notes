import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'license_codec.dart';

void main() => runApp(const KeygenApp());

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const _kSeed = 'owner_seed_hex';

class KeygenApp extends StatelessWidget {
  const KeygenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مولّد أكواد مذكراتي',
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
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  bool _loading = true;
  List<int>? _seed; // 32 بايت.

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? hex;
    try {
      hex = await _storage.read(key: _kSeed);
    } catch (_) {}
    setState(() {
      _seed = (hex != null && hex.length == 64) ? _hexToBytes(hex) : null;
      _loading = false;
    });
  }

  Future<void> _saveSeed(String hex) async {
    await _storage.write(key: _kSeed, value: hex);
    setState(() => _seed = _hexToBytes(hex));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_seed == null) return _SetupScreen(onSaved: _saveSeed);
    return _GeneratorScreen(seed: _seed!, onResetSeed: () async {
      await _storage.delete(key: _kSeed);
      setState(() => _seed = null);
    });
  }
}

/// شاشة الإعداد لأوّل مرّة: إدخال المفتاح الخاصّ أو توليد زوج جديد.
class _SetupScreen extends StatefulWidget {
  final Future<void> Function(String hex) onSaved;
  const _SetupScreen({required this.onSaved});

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  String? _generatedPub;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _useEntered() async {
    final hex =
        _ctrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
    if (hex.length != 64) {
      setState(() => _error = 'المفتاح يجب أن يكون 64 خانة (hex)');
      return;
    }
    await widget.onSaved(hex);
  }

  Future<void> _generateNew() async {
    final kp = await LicenseCodec.newKeyPair();
    setState(() {
      _ctrl.text = kp.seedHex;
      _generatedPub = kp.publicKeyB64;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد المولّد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'هذا المولّد يحمل مفتاحك الخاصّ ويبقى لديك أنت فقط. أدخل المفتاح '
              'الخاصّ الذي بحوزتك، أو ولّد زوجًا جديدًا (وحينها ضع المفتاح العامّ '
              'في التطبيق وأعد بناءه).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'المفتاح الخاصّ (Seed — 64 خانة hex)',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _useEntered,
              icon: const Icon(Icons.check),
              label: const Text('استخدام هذا المفتاح'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _generateNew,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('توليد زوج مفاتيح جديد'),
            ),
            if (_generatedPub != null) ...[
              const SizedBox(height: 16),
              const Text('المفتاح العامّ (ضعه في التطبيق):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _CopyBox(label: 'Public Key (Base64)', value: _generatedPub!),
              const SizedBox(height: 8),
              const Text(
                  '⚠️ احفظ المفتاح الخاصّ أعلاه في مكان آمن جدًّا — فقدانه يعني '
                  'عدم القدرة على توليد أكواد بعد ذلك.',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// شاشة توليد الأكواد.
class _GeneratorScreen extends StatefulWidget {
  final List<int> seed;
  final Future<void> Function() onResetSeed;
  const _GeneratorScreen({required this.seed, required this.onResetSeed});

  @override
  State<_GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<_GeneratorScreen> {
  final _deviceCtrl = TextEditingController();
  final _daysCtrl = TextEditingController(text: '30');
  bool _permanent = false;
  String? _key;
  String _pub = '...';

  static const _presets = [7, 30, 90, 180, 365];

  @override
  void initState() {
    super.initState();
    LicenseCodec.publicKeyB64(widget.seed)
        .then((v) => mounted ? setState(() => _pub = v) : null);
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final device = _deviceCtrl.text.trim();
    if (device.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل رقم الجهاز أولًا')));
      return;
    }
    int days = 0;
    if (!_permanent) {
      days = int.tryParse(_daysCtrl.text.trim()) ?? 0;
      if (days <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أدخل عدد أيام صحيح')));
        return;
      }
    }
    final key = await LicenseCodec.generate(
      deviceId: device,
      durationDays: _permanent ? 0 : days,
      seed: widget.seed,
    );
    if (!mounted) return;
    setState(() => _key = key);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مولّد أكواد التفعيل'),
        actions: [
          IconButton(
            tooltip: 'المفتاح العامّ / إعادة الضبط',
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
                      onPressed: () =>
                          setState(() => _daysCtrl.text = '$p'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.vpn_key),
              label: const Text('توليد الكود'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
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
                    Text('رمز التفعيل',
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
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ الكود')));
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
            const Text('المفتاح العامّ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
                'يجب أن يطابق المفتاح العامّ المدمج في التطبيق. إن لم يطابق، '
                'لن تُقبل الأكواد.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            _CopyBox(label: 'Public Key (Base64)', value: _pub),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('تغيير المفتاح الخاصّ؟'),
                    content: const Text(
                        'سيُحذف المفتاح الحالي من هذا الجهاز. تأكّد أنّك حفظته.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('حذف وتغيير')),
                    ],
                  ),
                );
                if (ok == true) await widget.onResetSeed();
              },
              icon: const Icon(Icons.key_off),
              label: const Text('تغيير المفتاح الخاصّ'),
            ),
          ],
        ),
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
