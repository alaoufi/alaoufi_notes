import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../backup/backup_screen.dart';
import '../categories/manage_categories_screen.dart';
import '../security/security_settings_screen.dart';
import '../trash/archive_screen.dart';
import '../trash/trash_screen.dart';
import 'settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: ListView(
        children: [
          _section(context, s.t('appearance')),

          // الوضع (نهاري/ليلي/النظام)
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(s.t('theme_mode')),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(s.t('mode_system'))),
                DropdownMenuItem(value: ThemeMode.light, child: Text(s.t('mode_light'))),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(s.t('mode_dark'))),
              ],
              onChanged: (v) => settings.setThemeMode(v ?? ThemeMode.system),
            ),
          ),

          // لون السمة
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: Text(s.t('theme_color')),
            subtitle: Wrap(
              spacing: 10,
              children: AppColors.themeSeeds.values.map((c) {
                final selected = c.value == settings.seedColor.value;
                return GestureDetector(
                  onTap: () => settings.setSeedColor(c),
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 6)]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          // حجم الخط
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(s.t('font_size')),
            subtitle: Slider(
              min: 0.85,
              max: 1.4,
              divisions: 11,
              label: '${(settings.fontScale * 100).round()}%',
              value: settings.fontScale,
              onChanged: settings.setFontScale,
            ),
          ),

          // نوع الخط (الخط الافتراضي للتطبيق والملاحظات)
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: const Text('نوع الخط'),
            trailing: DropdownButton<String>(
              value: settings.fontFamily,
              underline: const SizedBox.shrink(),
              onChanged: (v) {
                if (v != null) settings.setFontFamily(v);
              },
              items: [
                for (final f in SettingsProvider.fontFamilies)
                  DropdownMenuItem(
                    value: f,
                    child: Text(f, style: TextStyle(fontFamily: f)),
                  ),
              ],
            ),
          ),

          // إخفاء قائمة (نسخ/لصق/تحديد الكل) أثناء الكتابة
          SwitchListTile(
            secondary: const Icon(Icons.content_paste_off_outlined),
            title: const Text('إخفاء قائمة النسخ/اللصق'),
            subtitle: const Text(
                'تمنع ظهور شريط (نسخ/لصق/تحديد الكل) الذي قد يغطّي اختيار الخط والحجم أثناء التحرير.'),
            value: settings.hideSelectionMenu,
            onChanged: settings.setHideSelectionMenu,
          ),

          // مكان صفحة «معلومات عامة»
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('مكان «معلومات عامة»'),
            trailing: DropdownButton<InfoPlacement>(
              value: settings.infoPlacement,
              underline: const SizedBox.shrink(),
              onChanged: (v) {
                if (v != null) settings.setInfoPlacement(v);
              },
              items: const [
                DropdownMenuItem(
                    value: InfoPlacement.tab, child: Text('تبويب علوي')),
                DropdownMenuItem(
                    value: InfoPlacement.menu, child: Text('قائمة النقاط')),
                DropdownMenuItem(
                    value: InfoPlacement.drawer, child: Text('القائمة الجانبية')),
              ],
            ),
          ),

          // طريقة العرض
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: Text(s.t('layout')),
            trailing: SegmentedButton<NoteLayout>(
              segments: [
                ButtonSegment(value: NoteLayout.grid, label: Text(s.t('layout_grid'))),
                ButtonSegment(value: NoteLayout.list, label: Text(s.t('layout_list'))),
              ],
              selected: {settings.layout},
              onSelectionChanged: (v) => settings.setLayout(v.first),
            ),
          ),

          // اللغة
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(s.t('language')),
            trailing: DropdownButton<String>(
              value: settings.locale.languageCode,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'ar', child: Text(s.t('lang_ar'))),
                DropdownMenuItem(value: 'en', child: Text(s.t('lang_en'))),
              ],
              onChanged: (v) => settings.setLocale(Locale(v ?? 'ar')),
            ),
          ),

          // نغمة التنبيه
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('نغمة التنبيه'),
            trailing: DropdownButton<String>(
              value: settings.alarmTone,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'alarm', child: Text('إنذار')),
                DropdownMenuItem(value: 'chime', child: Text('لطيفة')),
                DropdownMenuItem(value: 'bell', child: Text('جرس')),
              ],
              onChanged: (v) {
                if (v != null) settings.setAlarmTone(v);
              },
            ),
          ),

          const Divider(),
          _section(context, s.t('security')),
          _nav(context, Icons.lock_outline, s.t('security'),
              const SecuritySettingsScreen()),

          const Divider(),
          _section(context, 'النسخ الاحتياطي'),
          _nav(context, Icons.backup_outlined, 'النسخ الاحتياطي والمشاركة السحابية',
              const BackupScreen()),

          const Divider(),
          _section(context, s.t('settings')),
          _nav(context, Icons.category_outlined, s.t('manage_categories'),
              const ManageCategoriesScreen()),
          _nav(context, Icons.archive_outlined, s.t('archived'),
              const ArchiveScreen()),
          _nav(context, Icons.delete_outline, s.t('trash'),
              const TrashScreen()),

          const Divider(),
          _section(context, s.t('about')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(s.t('about_desc'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _nav(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}
