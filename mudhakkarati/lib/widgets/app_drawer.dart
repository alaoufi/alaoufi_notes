import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/security_service.dart';
import '../features/backup/backup_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/categories/manage_categories_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/info/info_list_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/security/note_unlock.dart';
import '../features/security/secret_notes_screen.dart';
import '../features/security/security_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tags/tags_screen.dart';
import '../features/trash/archive_screen.dart';
import '../features/trash/trash_screen.dart';

/// القائمة الجانبية الرئيسية (مستوحاة من تطبيقات المذكرات الاحترافية).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;

    void go(Widget page) {
      Navigator.pop(context); // أغلق القائمة
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    Future<void> goSecret() async {
      Navigator.pop(context);
      final ok = await ensureUnlocked(context);
      if (ok && context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SecretNotesScreen()));
      }
    }

    Future<void> goInfo() async {
      Navigator.pop(context);
      if (await SecurityService.instance.isInfoLocked()) {
        if (!context.mounted) return;
        final ok = await ensureUnlocked(context);
        if (!ok) return;
      }
      if (context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InfoListScreen()));
      }
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: scheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.sticky_note_2, color: scheme.onPrimary, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    s.t('app_name'),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    s.t('about_desc'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: scheme.onPrimary.withOpacity(0.8), fontSize: 11),
                  ),
                ],
              ),
            ),
            _tile(context, Icons.calendar_month, s.t('calendar'),
                () => go(const CalendarScreen())),
            _tile(context, Icons.alarm, s.t('reminders'),
                () => go(const RemindersScreen())),
            _tile(context, Icons.star, s.t('favorites'),
                () => go(const FavoritesScreen())),
            _tile(context, Icons.lock, s.t('secret_notes'), goSecret),
            _tile(context, Icons.security, 'الحماية والقفل',
                () => go(const SecuritySettingsScreen())),
            _tile(context, Icons.tag, s.t('tags_page'),
                () => go(const TagsScreen())),
            _tile(context, Icons.menu_book_outlined, 'معلومات', goInfo),
            const Divider(),
            _tile(context, Icons.category_outlined, s.t('manage_categories'),
                () => go(const ManageCategoriesScreen())),
            _tile(context, Icons.archive_outlined, s.t('archived'),
                () => go(const ArchiveScreen())),
            _tile(context, Icons.delete_outline, s.t('trash'),
                () => go(const TrashScreen())),
            _tile(context, Icons.backup_outlined, s.t('backup'),
                () => go(const BackupScreen())),
            const Divider(),
            _tile(context, Icons.settings_outlined, s.t('settings'),
                () => go(const SettingsScreen())),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label,
      VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
