import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/note_gradient.dart';
import '../../data/models/enums.dart';
import '../../widgets/color_picker_sheet.dart';
import '../../widgets/paper_background.dart';
import '../backup/backup_screen.dart';
import '../categories/manage_categories_screen.dart';
import '../security/security_settings_screen.dart';
import '../trash/archive_screen.dart';
import '../trash/trash_screen.dart';
import 'settings_provider.dart';

/// شاشة الإعدادات — تصميم عصري مجمّع: بطاقات بارزة (ثلاثية الأبعاد) قابلة للطيّ،
/// كل مجموعة متشابهة في بطاقة واحدة لتنظيم أوضح.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // رأس عصري بتدرّج لوني.
          SliverAppBar.large(
            pinned: true,
            title: Text(s.t('settings'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            flexibleSpace: FlexibleSpaceBar(
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      scheme.primaryContainer.withOpacity(0.7),
                      scheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
            sliver: SliverList.list(
              children: [
                _groupCard(
                  context,
                  icon: Icons.palette_outlined,
                  title: s.t('appearance'),
                  subtitle: 'الوضع، اللون، الخط، اللغة',
                  initiallyExpanded: true,
                  children: _appearance(context, s, settings),
                ),
                _groupCard(
                  context,
                  icon: Icons.sticky_note_2_outlined,
                  title: 'الملاحظة الافتراضية',
                  subtitle: 'شكل الملاحظات الجديدة',
                  children: _noteDefaults(context, s, settings),
                ),
                _groupCard(
                  context,
                  icon: Icons.format_align_justify,
                  title: 'تسطير الصفحة',
                  subtitle: 'الخطوط خلف الكتابة',
                  children: _noteRuling(context, s, settings),
                ),
                _groupCard(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'التحرير والعرض',
                  subtitle: 'سلوك المحرّر وطريقة العرض',
                  children: _editingDisplay(context, s, settings),
                ),
                _groupCard(
                  context,
                  icon: Icons.shield_outlined,
                  title: 'الأمان والنسخ الاحتياطي',
                  children: [
                    _nav(context, Icons.lock_outline, s.t('security'),
                        const SecuritySettingsScreen()),
                    _nav(context, Icons.backup_outlined,
                        'النسخ الاحتياطي والمشاركة السحابية',
                        const BackupScreen()),
                  ],
                ),
                _groupCard(
                  context,
                  icon: Icons.folder_outlined,
                  title: 'التنظيم',
                  children: [
                    _nav(context, Icons.category_outlined,
                        s.t('manage_categories'),
                        const ManageCategoriesScreen()),
                    _nav(context, Icons.archive_outlined, s.t('archived'),
                        const ArchiveScreen()),
                    _nav(context, Icons.delete_outline, s.t('trash'),
                        const TrashScreen()),
                  ],
                ),
                _groupCard(
                  context,
                  icon: Icons.info_outline,
                  title: s.t('about'),
                  children: _about(context, s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== بطاقة مجموعة قابلة للطيّ (ثلاثية الأبعاد) =====================

  Widget _groupCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(14, 7, 14, 7),
      elevation: 4,
      shadowColor: scheme.shadow.withOpacity(0.5),
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // إزالة خطوط ExpansionTile العلوية/السفلية لمظهر أنظف.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  scheme.primaryContainer.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 23),
          ),
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          initiallyExpanded: initiallyExpanded,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          children: children,
        ),
      ),
    );
  }

  // ===================== المظهر =====================

  List<Widget> _appearance(BuildContext context, S s, SettingsProvider st) => [
        // الوضع (نهاري/ليلي/النظام)
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: Text(s.t('theme_mode')),
          trailing: DropdownButton<ThemeMode>(
            value: st.themeMode,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(
                  value: ThemeMode.system, child: Text(s.t('mode_system'))),
              DropdownMenuItem(
                  value: ThemeMode.light, child: Text(s.t('mode_light'))),
              DropdownMenuItem(
                  value: ThemeMode.dark, child: Text(s.t('mode_dark'))),
            ],
            onChanged: (v) => st.setThemeMode(v ?? ThemeMode.system),
          ),
        ),

        // لون السمة
        ListTile(
          leading: const Icon(Icons.color_lens_outlined),
          title: Text(s.t('theme_color')),
          subtitle: Wrap(
            spacing: 10,
            children: AppColors.themeSeeds.values.map((c) {
              final selected = c.value == st.seedColor.value;
              return GestureDetector(
                onTap: () => st.setSeedColor(c),
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

        // حجم الخط (واجهة التطبيق)
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text(s.t('font_size')),
          subtitle: Slider(
            min: 0.85,
            max: 1.4,
            divisions: 11,
            label: '${(st.fontScale * 100).round()}%',
            value: st.fontScale,
            onChanged: st.setFontScale,
          ),
        ),

        // نوع الخط
        ListTile(
          leading: const Icon(Icons.font_download_outlined),
          title: const Text('نوع الخط'),
          trailing: DropdownButton<String>(
            value: st.fontFamily,
            underline: const SizedBox.shrink(),
            onChanged: (v) {
              if (v != null) st.setFontFamily(v);
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

        // اللغة
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(s.t('language')),
          trailing: DropdownButton<String>(
            value: st.locale.languageCode,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: 'ar', child: Text(s.t('lang_ar'))),
              DropdownMenuItem(value: 'en', child: Text(s.t('lang_en'))),
            ],
            onChanged: (v) => st.setLocale(Locale(v ?? 'ar')),
          ),
        ),
      ];

  // ===================== الملاحظة الافتراضية (المظهر) =====================

  static const _styleNames = [
    'سادة', 'مسطّر', 'شبكي', 'نقاط',
    'شبكة دقيقة', 'نقاط كبيرة', 'أسطر', 'مربعات',
  ];

  List<Widget> _noteDefaults(BuildContext context, S s, SettingsProvider st) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final styleName = _styleNames[st.defaultBgStyle.clamp(0, 7)];
    final defGrad = NoteGradient.parse(st.defaultGradient);

    return [
      // معاينة حيّة
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: _NotePreview(settings: st),
      ),

      // لون الخلفية ونمط الصفحة
      ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: const Text('لون/تدرّج الخلفية ونمط الصفحة'),
        subtitle: Text(defGrad != null
            ? 'تدرّج لوني • النمط: $styleName'
            : 'النمط الحالي: $styleName'),
        trailing: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: defGrad == null
                ? AppColors.resolveNoteColor(st.defaultNoteColor, isDark)
                : null,
            gradient: defGrad?.toGradient(),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
        ),
        onTap: () async {
          final res = await showColorPicker(context, st.defaultNoteColor,
              currentStyle: st.defaultBgStyle,
              currentGradient: st.defaultGradient,
              currentOnLine: st.ruleOnLine,
              currentThickness: st.ruleThickness,
              currentOpacity: st.ruleOpacity,
              currentLineHeight: st.noteLineHeight);
          if (res != null) {
            await st.setDefaultNoteColor(res.value);
            if (res.bgStyle != null) await st.setDefaultBgStyle(res.bgStyle!);
            await st.setDefaultGradient(res.gradient);
            if (res.ruleOnLine != null) await st.setRuleOnLine(res.ruleOnLine!);
            if (res.ruleThickness != null) {
              await st.setRuleThickness(res.ruleThickness!);
            }
            if (res.ruleOpacity != null) {
              await st.setRuleOpacity(res.ruleOpacity!);
            }
            if (res.ruleLineHeight != null) {
              await st.setNoteLineHeight(res.ruleLineHeight!);
            }
          }
        },
      ),

      // خط المتن
      ListTile(
        leading: const Icon(Icons.text_fields),
        title: const Text('خط المتن'),
        trailing: DropdownButton<String>(
          value: st.noteFontFamily,
          underline: const SizedBox.shrink(),
          onChanged: (v) {
            if (v != null) st.setNoteFontFamily(v);
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

      // حجم خط المتن
      ListTile(
        leading: const Icon(Icons.format_size),
        title: const Text('حجم خط المتن'),
        subtitle: Slider(
          min: 12,
          max: 30,
          divisions: 18,
          label: st.noteFontSize.round().toString(),
          value: st.noteFontSize.clamp(12, 30),
          onChanged: st.setNoteFontSize,
        ),
      ),

      // تباعد الأسطر
      ListTile(
        leading: const Icon(Icons.format_line_spacing),
        title: const Text('تباعد الأسطر'),
        subtitle: Slider(
          min: 1.0,
          max: 2.6,
          divisions: 16,
          label: st.noteLineHeight.toStringAsFixed(1),
          value: st.noteLineHeight.clamp(1.0, 2.6),
          onChanged: st.setNoteLineHeight,
        ),
      ),

      // خط غامق
      SwitchListTile(
        secondary: const Icon(Icons.format_bold),
        title: const Text('خط غامق'),
        subtitle: const Text('يجعل خط متن الملاحظة غامقًا افتراضيًّا'),
        value: st.noteBold,
        onChanged: st.setNoteBold,
      ),
    ];
  }

  // ===================== تسطير الصفحة =====================

  List<Widget> _noteRuling(BuildContext context, S s, SettingsProvider st) => [
        // تفعيل/إلغاء التسطير افتراضيًّا (إلغاء ⇒ خلفية سادة بلا خطوط).
        SwitchListTile(
          secondary: const Icon(Icons.format_align_justify),
          title: const Text('إظهار التسطير'),
          subtitle: const Text('عند الإيقاف تكون الخلفية سادة بلا خطوط'),
          value: st.defaultBgStyle != 0,
          onChanged: (on) => st.setDefaultBgStyle(on ? 1 : 0),
        ),

        // محاذاة الكتابة: على السطر / بين السطرين
        ListTile(
          leading: const Icon(Icons.vertical_align_center),
          title: const Text('محاذاة الكتابة'),
          trailing: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('على السطر')),
              ButtonSegment(value: false, label: Text('بين السطرين')),
            ],
            selected: {st.ruleOnLine},
            onSelectionChanged: (v) => st.setRuleOnLine(v.first),
          ),
        ),

        // سماكة الأسطر
        ListTile(
          leading: const Icon(Icons.line_weight),
          title: const Text('سماكة الأسطر'),
          subtitle: Slider(
            min: 0.5,
            max: 3.0,
            divisions: 10,
            label: st.ruleThickness.toStringAsFixed(1),
            value: st.ruleThickness.clamp(0.5, 3.0),
            onChanged: st.setRuleThickness,
          ),
        ),

        // شفافية الأسطر
        ListTile(
          leading: const Icon(Icons.opacity),
          title: const Text('شفافية الأسطر'),
          subtitle: Slider(
            min: 0.03,
            max: 0.6,
            divisions: 19,
            label: '${(st.ruleOpacity * 100).round()}%',
            value: st.ruleOpacity.clamp(0.03, 0.6),
            onChanged: st.setRuleOpacity,
          ),
        ),
      ];

  // ===================== التحرير والعرض =====================

  List<Widget> _editingDisplay(
          BuildContext context, S s, SettingsProvider st) =>
      [
        // إخفاء قائمة (نسخ/لصق/تحديد الكل) أثناء الكتابة
        SwitchListTile(
          secondary: const Icon(Icons.content_paste_off_outlined),
          title: const Text('إخفاء قائمة النسخ/اللصق'),
          subtitle: const Text(
              'تمنع ظهور شريط (نسخ/لصق/تحديد الكل) الذي قد يغطّي اختيار الخط والحجم أثناء التحرير.'),
          value: st.hideSelectionMenu,
          onChanged: st.setHideSelectionMenu,
        ),

        // مكان صفحة «معلومات عامة»
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('مكان صفحة «معلومات»'),
          trailing: DropdownButton<InfoPlacement>(
            value: st.infoPlacement,
            underline: const SizedBox.shrink(),
            onChanged: (v) {
              if (v != null) st.setInfoPlacement(v);
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
              ButtonSegment(
                  value: NoteLayout.grid, label: Text(s.t('layout_grid'))),
              ButtonSegment(
                  value: NoteLayout.list, label: Text(s.t('layout_list'))),
            ],
            selected: {st.layout},
            onSelectionChanged: (v) => st.setLayout(v.first),
          ),
        ),

        // نغمة التنبيه
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('نغمة التنبيه'),
          trailing: DropdownButton<String>(
            value: st.alarmTone,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'alarm', child: Text('إنذار')),
              DropdownMenuItem(value: 'chime', child: Text('لطيفة')),
              DropdownMenuItem(value: 'bell', child: Text('جرس')),
            ],
            onChanged: (v) {
              if (v != null) st.setAlarmTone(v);
            },
          ),
        ),
      ];

  // ===================== حول التطبيق =====================

  List<Widget> _about(BuildContext context, S s) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(s.t('about_desc'),
              style: Theme.of(context).textTheme.bodySmall),
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final info = snap.data;
            final label = info == null
                ? '...'
                : 'الإصدار ${info.version}  •  رقم النسخة ${info.buildNumber}';
            return ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('إصدار التطبيق'),
              subtitle: Text(label),
            );
          },
        ),
      ];

  Widget _nav(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}

/// معاينة حيّة لشكل الملاحظة الافتراضية (لون + تسطير + خط المتن).
class _NotePreview extends StatelessWidget {
  final SettingsProvider settings;
  const _NotePreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.resolveNoteColor(settings.defaultNoteColor, isDark);
    final grad = NoteGradient.parse(settings.defaultGradient);
    final onBg = grad != null
        ? grad.onColor
        : (ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black87);
    final gap = settings.noteFontSize * settings.noteLineHeight;

    return Container(
      decoration: BoxDecoration(
        color: grad == null ? bg : null,
        gradient: grad?.toGradient(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: PaperBackground(
        style: settings.defaultBgStyle,
        lineColor: onBg,
        gap: gap,
        thickness: settings.ruleThickness,
        opacity: settings.ruleOpacity,
        onLine: settings.ruleOnLine,
        fontSize: settings.noteFontSize,
        topPadding: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in const [
                'مثال على نص الملاحظة',
                'تنتظم الكتابة مع التسطير',
                'حسب الإعدادات المختارة',
              ])
                Text(
                  line,
                  style: TextStyle(
                    color: onBg,
                    fontFamily: settings.noteFontFamily,
                    fontSize: settings.noteFontSize,
                    height: settings.noteLineHeight,
                    fontWeight:
                        settings.noteBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
