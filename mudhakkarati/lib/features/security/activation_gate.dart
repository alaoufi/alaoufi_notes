import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/license_service.dart';

/// شاشة تفعيل التطبيق (مربوط بالجهاز). تظهر قبل المحتوى إن لم يُفعّل.
class ActivationGate extends StatefulWidget {
  final Widget child;
  const ActivationGate({super.key, required this.child});

  @override
  State<ActivationGate> createState() => _ActivationGateState();
}

class _ActivationGateState extends State<ActivationGate> {
  bool _checking = true;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await LicenseService.instance.isActivated();
    if (mounted) {
      setState(() {
        _activated = ok;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_activated) return widget.child;
    return _ActivationScreen(
        onActivated: () => setState(() => _activated = true));
  }
}

class _ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  const _ActivationScreen({required this.onActivated});

  @override
  State<_ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<_ActivationScreen> {
  final _codeCtrl = TextEditingController();
  String _deviceId = '...';
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    LicenseService.instance
        .deviceIdPretty()
        .then((v) => mounted ? setState(() => _deviceId = v) : null);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _error = false;
    });
    final ok = await LicenseService.instance.tryActivate(_codeCtrl.text);
    if (!mounted) return;
    if (ok) {
      widget.onActivated();
    } else {
      setState(() {
        _busy = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined, size: 64, color: scheme.primary),
                const SizedBox(height: 16),
                Text('تفعيل التطبيق',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'هذه النسخة مرخّصة لجهاز واحد. أرسل «رقم الجهاز» أدناه '
                  'للحصول على رمز التفعيل.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // رقم الجهاز.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text('رقم الجهاز',
                          style: TextStyle(color: scheme.primary, fontSize: 12)),
                      const SizedBox(height: 6),
                      SelectableText(
                        _deviceId,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _deviceId));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ رقم الجهاز')));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ رقم الجهاز'),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'رمز التفعيل',
                    hintText: 'ألصق الرمز هنا',
                    errorText: _error ? 'رمز غير صحيح لهذا الجهاز' : null,
                    prefixIcon: const Icon(Icons.vpn_key),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _activate,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_open),
                    label: const Text('تفعيل'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
