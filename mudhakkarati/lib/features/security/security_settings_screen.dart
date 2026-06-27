import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/license_service.dart';
import '../../services/security_service.dart';
import '../../widgets/ui_kit.dart';
import 'pin_entry.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _sec = SecurityService.instance;
  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _loaded = false;
  LicenseInfo? _license;
  String _deviceId = '…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _lockEnabled = await _sec.isLockEnabled();
    _biometricEnabled = await _sec.isBiometricEnabled();
    _biometricAvailable = await _sec.canUseBiometrics();
    _license = await LicenseService.instance.info();
    _deviceId = await LicenseService.instance.deviceIdPretty();
    setState(() => _loaded = true);
  }

  Future<void> _setupPin() async {
    final s = S.of(context);
    String? first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: PinEntry(
              title: first == null ? s.t('set_pin') : s.t('confirm_pin'),
              onSubmit: (pin) async {
                if (first == null) {
                  setSheet(() => first = pin);
                  return false; // اطلب التأكيد دون إغلاق.
                }
                if (first == pin) {
                  await _sec.setPin(pin);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                  return true;
                }
                setSheet(() => first = null); // غير متطابق، أعد البداية.
                return false;
              },
            ),
          );
        },
      ),
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: gradientAppBar(context, s.t('security')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const GradientIcon(Icons.lock_outline),
                  title: Text(s.t('app_lock'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s.t('use_pin')),
                  value: _lockEnabled,
                  onChanged: (v) async {
                    if (v) {
                      await _setupPin();
                    } else {
                      await _sec.disableLock();
                      await _load();
                    }
                  },
                ),
                if (_lockEnabled)
                  ListTile(
                    leading: const Icon(Icons.password),
                    title: Text(s.t('set_pin')),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: _setupPin,
                  ),
                if (_lockEnabled && _biometricAvailable)
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(s.t('use_biometric')),
                    value: _biometricEnabled,
                    onChanged: (v) async {
                      await _sec.setBiometric(v);
                      await _load();
                    },
                  ),
              ],
            ),
          ),
          // التفعيل: الحالة + رقم الجهاز + إلغاء التفعيل (لاختبار دورة التفعيل).
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.verified_user_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Text('التفعيل',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 10),
                  Text('الحالة: ${_licenseStatusText()}'),
                  const SizedBox(height: 4),
                  Text('رقم الجهاز: $_deviceId',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _deactivate,
                    icon: Icon(Icons.lock_reset, size: 18, color: scheme.error),
                    label: Text('إلغاء التفعيل (لاختبار التفعيل)',
                        style: TextStyle(color: scheme.error)),
                  ),
                ],
              ),
            ),
          ),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: scheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'يمكنك قفل ملاحظة معينة من قائمة خيارات الملاحظة (اضغط مطولاً على الملاحظة). يتطلب فتحها الرقم السري أو البصمة.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _licenseStatusText() {
    final l = _license;
    if (l == null) return '—';
    switch (l.state) {
      case LicenseState.disabled:
        return 'وضع تطوير (غير مقفل)';
      case LicenseState.none:
        return 'غير مفعّل';
      case LicenseState.active:
        return l.permanent ? 'مفعّل (دائم)' : 'مفعّل — متبقّي ${l.daysLeft} يوم';
      case LicenseState.expired:
        return 'منتهٍ';
    }
  }

  Future<void> _deactivate() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء التفعيل؟'),
        content: const Text(
            'سيُمسح سجلّ التفعيل، وتظهر شاشة التفعيل عند عودتك للتطبيق. (للاختبار)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إلغاء التفعيل')),
        ],
      ),
    );
    if (ok != true) return;
    await LicenseService.instance.deactivate();
    await _load();
    messenger.showSnackBar(const SnackBar(
        content: Text('أُلغي التفعيل — اخرج من التطبيق وارجع إليه لتظهر شاشة التفعيل')));
  }
}
