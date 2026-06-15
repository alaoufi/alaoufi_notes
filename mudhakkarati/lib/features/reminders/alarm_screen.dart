import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/notification_service.dart';

/// شاشة المنبّه داخل التطبيق — تظهر عند الضغط على تذكير حرج: عنوان/وصف/وقت
/// مع زرّ «تم الإنجاز» وزرّ «تأجيل» (خيارات 5/10/15/30/60 دقيقة).
class AlarmScreen extends StatelessWidget {
  final Map<String, String> info;
  const AlarmScreen({super.key, required this.info});

  int get _base => int.tryParse(info['base'] ?? '') ?? 0;
  int? get _noteId {
    final n = int.tryParse(info['note'] ?? '');
    return (n == null || n < 0) ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final now = TimeOfDay.now();
    final date = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFFB71C1C)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Icon(Icons.crisis_alert, color: Colors.white, size: 56),
                const Spacer(),
                // الوقت الكبير.
                Text('${two(now.hour)}:${two(now.minute)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold)),
                Text('${date.year}/${two(date.month)}/${two(date.day)}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 16)),
                const SizedBox(height: 28),
                // العنوان والوصف.
                Text(info['title'] ?? '⏰',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
                if ((info['body'] ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(info['body']!,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 16)),
                ],
                const Spacer(),
                // تأجيل.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _snooze(context, s),
                  icon: const Icon(Icons.snooze),
                  label: Text(s.t('alarm_snooze')),
                ),
                const SizedBox(height: 12),
                // تم الإنجاز.
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB71C1C),
                    minimumSize: const Size.fromHeight(58),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await NotificationService.instance.acknowledgeAlarm(_base);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: Text(s.t('alarm_done')),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _snooze(BuildContext context, S s) async {
    final mins = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in const [5, 10, 15, 30, 60])
              ListTile(
                leading: const Icon(Icons.snooze),
                title: Text('$m ${s.t('minutes')}'),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (mins == null) return;
    await NotificationService.instance.snoozeAlarm(
      _base,
      info['title'] ?? '⏰',
      info['body'] ?? '',
      mins,
      _noteId,
    );
    if (context.mounted) Navigator.pop(context);
  }
}
