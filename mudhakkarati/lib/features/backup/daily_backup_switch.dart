import 'package:flutter/material.dart';

import '../../services/backup_service.dart';

/// مفتاح تفعيل/إيقاف النسخة الاحتياطية اليومية التلقائية (بضغطة واحدة).
class DailyBackupSwitch extends StatefulWidget {
  const DailyBackupSwitch({super.key});

  @override
  State<DailyBackupSwitch> createState() => _DailyBackupSwitchState();
}

class _DailyBackupSwitchState extends State<DailyBackupSwitch> {
  bool _enabled = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await BackupService.instance.autoBackupEnabled();
    if (mounted) setState(() {
      _enabled = on;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _busy = true);
    try {
      if (v) {
        await BackupService.instance.enableDailyAutoBackup();
      } else {
        await BackupService.instance.setAutoBackupEnabled(false);
      }
      if (!mounted) return;
      setState(() {
        _enabled = v;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(v
              ? 'تم تفعيل النسخة اليومية التلقائية ✓'
              : 'أُوقفت النسخة التلقائية')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.event_repeat),
      title: const Text('نسخة احتياطية يومية تلقائية'),
      subtitle: const Text('تحفظ نسخة من ملاحظاتك يوميًّا تلقائيًّا'),
      value: _enabled,
      onChanged: (_loaded && !_busy) ? _toggle : null,
    );
  }
}
