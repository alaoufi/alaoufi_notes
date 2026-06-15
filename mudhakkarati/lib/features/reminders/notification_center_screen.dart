import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import 'reminders_provider.dart';

/// مركز التنبيهات: يعرض التذكيرات مجمّعة (اليوم/القادمة/المتأخرة) مع بحث.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _q = '';

  String _titleOf(ReminderView v) {
    final t = v.note?.title.trim();
    if (t != null && t.isNotEmpty) return t;
    final st = v.reminder.title?.trim();
    return (st != null && st.isNotEmpty) ? st : 'تذكير';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.watch<RemindersProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final items = provider.items
        .where((v) =>
            _q.isEmpty || _titleOf(v).toLowerCase().contains(_q.toLowerCase()))
        .toList();

    final overdue = <ReminderView>[];
    final todayL = <ReminderView>[];
    final upcoming = <ReminderView>[];
    for (final v in items) {
      final r = v.reminder;
      if (r.repeat != ReminderRepeat.once) {
        upcoming.add(v); // المتكرّرة تُعتبر قادمة
      } else if (r.time.isBefore(now)) {
        if (r.isActive) overdue.add(v);
      } else if (r.time.isBefore(tomorrow)) {
        todayL.add(v);
      } else {
        upcoming.add(v);
      }
    }
    int byTime(ReminderView a, ReminderView b) =>
        a.reminder.time.compareTo(b.reminder.time);
    overdue.sort(byTime);
    todayL.sort(byTime);
    upcoming.sort(byTime);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('notif_center'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: s.t('search'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Expanded(
            child: (overdue.isEmpty && todayL.isEmpty && upcoming.isEmpty)
                ? Center(child: Text(s.t('no_reminders')))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      _section(s.t('nc_overdue'), Icons.error_outline,
                          Colors.red, overdue),
                      _section(s.t('nc_today'), Icons.today,
                          Colors.blue, todayL),
                      _section(s.t('nc_upcoming'), Icons.upcoming,
                          Colors.teal, upcoming),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(
      String title, IconData icon, Color color, List<ReminderView> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 6),
            Text('(${list.length})',
                style: TextStyle(color: color, fontSize: 12)),
          ]),
        ),
        for (final v in list) _tile(v, color),
      ],
    );
  }

  Widget _tile(ReminderView v, Color sectionColor) {
    final r = v.reminder;
    final t = r.time;
    String two(int n) => n.toString().padLeft(2, '0');
    final when = '${t.year}/${two(t.month)}/${two(t.day)}  '
        '${two(t.hour)}:${two(t.minute)}';
    final impColor = switch (r.importance) {
      ReminderImportance.low => const Color(0xFF78909C),
      ReminderImportance.medium => const Color(0xFF42A5F5),
      ReminderImportance.high => const Color(0xFFEF6C00),
      ReminderImportance.critical => const Color(0xFFE53935),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          radius: 6,
          backgroundColor: impColor,
        ),
        title: Text(_titleOf(v),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(when, style: const TextStyle(fontSize: 12)),
        trailing: r.repeat != ReminderRepeat.once
            ? const Icon(Icons.repeat, size: 18)
            : null,
      ),
    );
  }
}
