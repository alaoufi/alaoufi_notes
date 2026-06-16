import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/l10n/app_strings.dart';
import '../features/backup/backup_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/categories/manage_categories_screen.dart';
import '../features/cleanup/cleanup_screen.dart';
import '../features/insights/weekly_summary_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/help/help_guide_screen.dart';
import '../features/info/info_list_screen.dart';
import '../features/security/info_lock.dart';
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
      if (!context.mounted) return;
      if (!await ensureInfoUnlocked(context)) return;
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
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snap) {
                      final info = snap.data;
                      if (info == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'v${info.version} • #${info.buildNumber}',
                          style: TextStyle(
                              color: scheme.onPrimary.withOpacity(0.7),
                              fontSize: 11),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // دليل الاستخدام بارز أعلى القائمة (يفتح حسب اللغة المختارة).
            ListTile(
              leading: Icon(Icons.auto_stories, color: scheme.primary),
              title: Text(s.t('user_guide'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: scheme.primary)),
              onTap: () => go(const HelpGuideScreen()),
            ),
            const Divider(height: 1),
            // مجموعات قابلة للطيّ (تمدّد/انكماش) لتنظيم أوضح.
            _group(context, Icons.explore_outlined, s.t('group_quick'),
                initiallyExpanded: true, children: [
              _tile(context, Icons.calendar_month, s.t('calendar'),
                  () => go(const CalendarScreen())),
              _tile(context, Icons.alarm, s.t('reminders'),
                  () => go(const RemindersScreen())),
              _tile(context, Icons.star, s.t('favorites'),
                  () => go(const FavoritesScreen())),
              _tile(context, Icons.tag, s.t('tags_page'),
                  () => go(const TagsScreen())),
              _tile(context, Icons.menu_book_outlined, s.t('info'), goInfo),
            ]),
            _group(context, Icons.shield_outlined, s.t('security'),
                children: [
              _tile(context, Icons.lock, s.t('secret_notes'), goSecret),
              _tile(context, Icons.security, s.t('security_lock'),
                  () => go(const SecuritySettingsScreen())),
            ]),
            _group(context, Icons.handyman_outlined, s.t('group_tools'),
                children: [
              _tile(context, Icons.cleaning_services_outlined, s.t('cleanup'),
                  () => go(const CleanupScreen())),
              _tile(context, Icons.insights_outlined, s.t('weekly_summary'),
                  () => go(const WeeklySummaryScreen())),
              _tile(context, Icons.category_outlined, s.t('manage_categories'),
                  () => go(const ManageCategoriesScreen())),
            ]),
            _group(context, Icons.backup_outlined, s.t('group_backup'),
                initiallyExpanded: true, children: [
              _tile(context, Icons.archive_outlined, s.t('archived'),
                  () => go(const ArchiveScreen())),
              _tile(context, Icons.delete_outline, s.t('trash'),
                  () => go(const TrashScreen())),
              _tile(context, Icons.backup_outlined, s.t('backup'),
                  () => go(const BackupScreen())),
            ]),
            const Divider(),
            _tile(context, Icons.auto_stories, s.t('user_guide'),
                () => go(const HelpGuideScreen())),
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
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  /// مجموعة قابلة للطيّ (تمدّد/انكماش) تضمّ عناصر متشابهة.
  Widget _group(BuildContext context, IconData icon, String title,
      {required List<Widget> children, bool initiallyExpanded = false}) {
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsetsDirectional.only(start: 12),
      children: children,
    );
  }
}
