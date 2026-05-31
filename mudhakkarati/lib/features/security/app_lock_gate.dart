import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/security_service.dart';
import '../home/root_screen.dart';
import 'pin_entry.dart';

/// بوابة تتحقق من قفل التطبيق قبل عرض المحتوى، وتعيد القفل عند العودة من الخلفية.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool? _locked; // null = جارٍ التحقق
  bool _checking = true;
  bool _lockEnabled = false;
  bool _authing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockEnabled) return;
    // عند ذهاب التطبيق للخلفية: أعد القفل ليُطلب الفتح عند العودة.
    if (state == AppLifecycleState.paused) {
      if (_locked != true && mounted) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed) {
      if (_locked == true) _tryBiometric();
    }
  }

  Future<void> _check() async {
    _lockEnabled = await SecurityService.instance.isLockEnabled();
    if (!_lockEnabled) {
      setState(() {
        _locked = false;
        _checking = false;
      });
      return;
    }
    setState(() {
      _locked = true;
      _checking = false;
    });
    _tryBiometric();
  }

  /// محاولة فتح القفل بالبصمة تلقائيًا إن كانت مفعّلة.
  Future<void> _tryBiometric() async {
    if (_authing) return;
    if (!await SecurityService.instance.isBiometricEnabled()) return;
    _authing = true;
    try {
      final ok = await SecurityService.instance
          .authenticateBiometric('افتح قفل Alaoufi Notes');
      if (ok && mounted) setState(() => _locked = false);
    } finally {
      _authing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_locked == true) {
      return Scaffold(
        body: SafeArea(
          child: PinEntry(
            title: S.of(context).t('enter_pin'),
            showBiometric: true,
            onSubmit: (pin) async {
              final ok = await SecurityService.instance.verifyPin(pin);
              if (ok && mounted) setState(() => _locked = false);
              return ok;
            },
            onBiometric: () async {
              final ok = await SecurityService.instance
                  .authenticateBiometric('افتح قفل Alaoufi Notes');
              if (ok && mounted) setState(() => _locked = false);
              return ok;
            },
          ),
        ),
      );
    }
    return const RootScreen();
  }
}
