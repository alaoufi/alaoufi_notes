import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

/// شاشة «دليل ومساعدة» تفاعلية بتصميم عصريّ ثلاثيّ الأبعاد: كل أداة تظهر
/// بأيقونتها الحقيقية + وظيفتها. محتواها **متوافق مع لغة التطبيق** (يتبع اللغة
/// المختارة، مع رجوع تلقائيّ للإنجليزية لِما لم يُترجَم بعد).
class HelpGuideScreen extends StatelessWidget {
  const HelpGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final lang = S.of(context).locale.languageCode;
    final chrome = _chrome[lang] ?? _chrome['en']!;
    final sections = _sectionsByLang[lang] ?? _sectionsByLang['en']!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _Header(
              dark: dark,
              scheme: scheme,
              title: chrome.title,
              subtitle: chrome.subtitle),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
            sliver: SliverList.list(
              children: [
                for (final sec in sections)
                  _SectionCard(
                      section: sec, dark: dark, itemsLabel: chrome.items),
                const SizedBox(height: 8),
                Center(
                  child: Text(chrome.updated,
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withOpacity(0.4))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ رأس ثلاثيّ الأبعاد ============================
class _Header extends StatelessWidget {
  final bool dark;
  final ColorScheme scheme;
  final String title;
  final String subtitle;
  const _Header(
      {required this.dark,
      required this.scheme,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 188,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      title: Text(title),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                scheme.primary,
                Color.alphaBlend(
                    Colors.black.withOpacity(0.18), scheme.primary),
                scheme.tertiary,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                left: -20,
                child: _blob(scheme.onPrimary.withOpacity(0.10), 140),
              ),
              Positioned(
                bottom: -40,
                right: -10,
                child: _blob(scheme.onPrimary.withOpacity(0.08), 120),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.onPrimary.withOpacity(0.95),
                              scheme.onPrimary.withOpacity(0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.28),
                                offset: const Offset(0, 8),
                                blurRadius: 16,
                                spreadRadius: -2),
                          ],
                        ),
                        child: Icon(Icons.auto_stories,
                            color: scheme.primary, size: 34),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: scheme.onPrimary.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ============================ بطاقة قسم ثلاثية الأبعاد ============================
class _SectionCard extends StatelessWidget {
  final _Section section;
  final bool dark;
  final String itemsLabel;
  const _SectionCard(
      {required this.section, required this.dark, required this.itemsLabel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = dark ? const Color(0xFF1E2230) : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surface,
            Color.alphaBlend(section.color.withOpacity(0.06), surface),
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.45 : 0.12),
              offset: const Offset(0, 10),
              blurRadius: 24,
              spreadRadius: -6),
          BoxShadow(
              color: Colors.white.withOpacity(dark ? 0.04 : 0.9),
              offset: const Offset(-3, -3),
              blurRadius: 8),
        ],
        border: Border.all(color: section.color.withOpacity(0.18)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: section.expanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: _Icon3D(icon: section.icon, accent: section.color, size: 46),
          title: Text(section.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: scheme.onSurface)),
          subtitle: Text('${section.items.length} $itemsLabel',
              style: TextStyle(
                  fontSize: 11.5, color: scheme.onSurface.withOpacity(0.5))),
          children: [
            for (final it in section.items)
              _ToolRow(item: it, accent: section.color, dark: dark),
          ],
        ),
      ),
    );
  }
}

// ============================ صفّ أداة (أيقونة + وظيفة) ============================
class _ToolRow extends StatelessWidget {
  final _Item item;
  final Color accent;
  final bool dark;
  const _ToolRow(
      {required this.item, required this.accent, required this.dark});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color:
            dark ? Colors.white.withOpacity(0.03) : accent.withOpacity(0.05),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Icon3D(icon: item.icon, accent: accent, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(item.desc,
                    style: TextStyle(
                        fontSize: 12.8,
                        height: 1.4,
                        color: scheme.onSurface.withOpacity(0.72))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================ أيقونة مرتفعة (تأثير ثلاثيّ الأبعاد) ============================
class _Icon3D extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  const _Icon3D(
      {required this.icon, required this.accent, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withOpacity(0.25), accent),
            accent,
            Color.alphaBlend(Colors.black.withOpacity(0.22), accent),
          ],
        ),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.5),
              offset: const Offset(0, 5),
              blurRadius: 10,
              spreadRadius: -2),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

// ============================ النماذج ============================
class _Item {
  final IconData icon;
  final String title;
  final String desc;
  const _Item(this.icon, this.title, this.desc);
}

class _Section {
  final String title;
  final IconData icon;
  final Color color;
  final bool expanded;
  final List<_Item> items;
  const _Section(this.title, this.icon, this.color, this.items,
      {this.expanded = false});
}

class _Chrome {
  final String title;
  final String subtitle;
  final String items;
  final String updated;
  const _Chrome(this.title, this.subtitle, this.items, this.updated);
}

// ألوان موحّدة للأقسام (مشتركة بين اللغات).
const _c1 = Color(0xFF5C6BC0); // إنشاء
const _c2 = Color(0xFF26A69A); // شريط التنسيق
const _c3 = Color(0xFFEF6C00); // أعلى المحرّر
const _c4 = Color(0xFF42A5F5); // الرئيسية
const _c5 = Color(0xFF8E24AA); // الاتجاه
const _c6 = Color(0xFFE53935); // الأمان
const _c7 = Color(0xFF00897B); // المزامنة
const _c8 = Color(0xFF6D4C41); // أدوات

const _chrome = <String, _Chrome>{
  'en': _Chrome('Guide & Help', 'Every tool — its shape and function',
      'items', 'Last updated: 2026‑06‑13'),
  'ar': _Chrome('دليل ومساعدة', 'كل أداة وشكلها ووظيفتها', 'عنصر',
      'آخر تحديث: 2026‑06‑13'),
};

final _sectionsByLang = <String, List<_Section>>{
  'en': _sectionsEn,
  'ar': _sectionsAr,
};

// ----------------------------- الإنجليزية -----------------------------
const _sectionsEn = <_Section>[
  _Section('Create a note (+)', Icons.add_circle, _c1, [
    _Item(Icons.edit_note, 'Note', 'A plain text note (the default) with an independent direction per line.'),
    _Item(Icons.checklist, 'Checklist', 'Lines with checkboxes you can tick (✓).'),
    _Item(Icons.mic, 'Voice note', 'Record and save an audio note.'),
    _Item(Icons.image, 'Image', 'Attach an image from gallery or camera.'),
    _Item(Icons.dashboard_customize_outlined, 'Template', 'Start from a ready‑made template.'),
    _Item(Icons.today, "Today's note", "Open/create a note for today's date."),
  ], expanded: true),
  _Section('Formatting bar', Icons.text_format, _c2, [
    _Item(Icons.undo, 'Undo / Redo', 'Undo or redo your last change.'),
    _Item(Icons.font_download_outlined, 'Font', 'Pick the font family.'),
    _Item(Icons.format_size, 'Font size', 'Increase or decrease text size.'),
    _Item(Icons.format_bold, 'Bold', 'Bold the selected text.'),
    _Item(Icons.format_italic, 'Italic', 'Italicize the selected text.'),
    _Item(Icons.format_underlined, 'Underline', 'Underline the selected text.'),
    _Item(Icons.format_strikethrough, 'Strikethrough', 'Strike through the selected text.'),
    _Item(Icons.format_color_text, 'Text color', 'Change the letters color.'),
    _Item(Icons.format_color_fill, 'Highlight', 'Highlight the text background.'),
    _Item(Icons.title, 'Headings', 'Format a heading (H1/H2/H3).'),
    _Item(Icons.format_list_bulleted, 'Bulleted list', 'A list with bullets.'),
    _Item(Icons.format_list_numbered, 'Numbered list', 'A numbered list.'),
    _Item(Icons.format_quote, 'Quote', 'A quote block with a side bar.'),
    _Item(Icons.format_align_right, 'Alignment', 'Right / center / left / justify.'),
    _Item(Icons.format_line_spacing, 'Line spacing', 'Selected lines only: 1.0–2.0, no ruling.'),
    _Item(Icons.format_clear, 'Clear formatting', 'Remove all formatting from the selection (keeps the text).'),
    _Item(Icons.content_paste, 'Paste menu', 'Show/hide the copy & paste menu.'),
    _Item(Icons.picture_as_pdf, 'Export PDF', 'Save the note as a formatted PDF.'),
    _Item(Icons.description, 'Export Word', 'Save a ‎.doc file that opens in Word with formatting.'),
  ]),
  _Section('Editor top tools', Icons.tune, _c3, [
    _Item(Icons.push_pin, 'Pin', 'Pin the note to the top of the list.'),
    _Item(Icons.palette_outlined, 'Color & page', 'Background color, page style, ruling and spacing.'),
    _Item(Icons.star, 'Favorite', 'Mark the note as a favorite.'),
    _Item(Icons.alarm, 'Reminder', 'One‑time or recurring (with weekdays).'),
    _Item(Icons.label_outline, 'Tags', 'Add/remove tags (#) for the note.'),
    _Item(Icons.more_vert, 'More', 'Details, delete, archive, share.'),
  ]),
  _Section('Home & navigation', Icons.home_outlined, _c4, [
    _Item(Icons.search, 'Search', 'Instant search in titles and content.'),
    _Item(Icons.tune, 'Advanced search', 'Filter by type/category/tag/date.'),
    _Item(Icons.calendar_month, 'Calendar', 'View notes and reminders by date.'),
    _Item(Icons.grid_view_outlined, 'Toggle view', 'Switch between grid and list.'),
    _Item(Icons.label, 'Categories', 'Chips to filter notes by category.'),
  ]),
  _Section('Text direction (feature)', Icons.format_textdirection_r_to_l, _c5, [
    _Item(Icons.subdirectory_arrow_right, 'Per‑line direction', 'Each line takes its direction from its first real letter.'),
    _Item(Icons.short_text, 'Symbols stay at start', 'Leading (- * • 1.) are ignored when detecting, and stay at the line start.'),
  ]),
  _Section('Security & privacy', Icons.shield_outlined, _c6, [
    _Item(Icons.lock, 'Lock note', 'Protect a note with a PIN.'),
    _Item(Icons.visibility_off, 'Privacy mode', 'Hide card contents, show titles only.'),
    _Item(Icons.vpn_key, 'Passwords', 'A note type for login data, locked by default.'),
    _Item(Icons.screenshot_monitor, 'Screenshot protection', 'Block screenshots for sensitive notes.'),
  ]),
  _Section('Backup & sync', Icons.cloud_sync, _c7, [
    _Item(Icons.backup_outlined, 'Backup', 'Save/restore a copy of all your notes.'),
    _Item(Icons.cloud, 'Google Drive', 'Real two‑way sync across your devices.'),
    _Item(Icons.dns_outlined, 'WebDAV', 'Sync with a private server (Nextcloud, etc.).'),
    _Item(Icons.enhanced_encryption, 'E2E encryption', 'Your data is encrypted on your device before upload.'),
    _Item(Icons.sync, 'Auto sync', 'Runs when you open the app, with a light status bar.'),
  ]),
  _Section('Tools & maintenance', Icons.handyman_outlined, _c8, [
    _Item(Icons.insights_outlined, 'Weekly summary', 'A look at your week activity.'),
    _Item(Icons.cleaning_services_outlined, 'Cleanup', 'Remove empty/duplicate notes.'),
    _Item(Icons.category_outlined, 'Manage categories', 'Create and edit categories and colors.'),
    _Item(Icons.archive_outlined, 'Archive', 'Archived notes.'),
    _Item(Icons.delete_outline, 'Trash', 'Restore or permanently delete removed notes.'),
    _Item(Icons.settings_outlined, 'Settings', 'Default font/size/spacing and color for the page.'),
  ]),
];

// ----------------------------- العربية -----------------------------
const _sectionsAr = <_Section>[
  _Section('إنشاء ملاحظة (زرّ +)', Icons.add_circle, _c1, [
    _Item(Icons.edit_note, 'ملاحظة', 'ملاحظة نصّية عادية (الأصل) باتجاه مستقلّ لكل سطر.'),
    _Item(Icons.checklist, 'قائمة مهام', 'أسطر بمربعات اختيار يمكن تعليمها (✓).'),
    _Item(Icons.mic, 'تسجيل صوتي', 'تسجيل ملاحظة صوتية وحفظها.'),
    _Item(Icons.image, 'صورة', 'إرفاق صورة من المعرض أو الكاميرا.'),
    _Item(Icons.dashboard_customize_outlined, 'قالب جاهز', 'بدء ملاحظة من قالب معدّ مسبقًا.'),
    _Item(Icons.today, 'ملاحظة اليوم', 'تفتح/تنشئ ملاحظة مخصّصة لتاريخ اليوم.'),
  ], expanded: true),
  _Section('شريط التنسيق', Icons.text_format, _c2, [
    _Item(Icons.undo, 'تراجع / إعادة', 'التراجع عن آخر تغيير أو إعادته.'),
    _Item(Icons.font_download_outlined, 'الخط', 'اختيار نوع الخط من قائمة واسعة.'),
    _Item(Icons.format_size, 'حجم الخط', 'تكبير/تصغير حجم النص.'),
    _Item(Icons.format_bold, 'غامق', 'تعريض النص المحدَّد.'),
    _Item(Icons.format_italic, 'مائل', 'إمالة النص المحدَّد.'),
    _Item(Icons.format_underlined, 'تسطير', 'خطّ تحت النص المحدَّد.'),
    _Item(Icons.format_strikethrough, 'شطب', 'خطّ في منتصف النص المحدَّد.'),
    _Item(Icons.format_color_text, 'لون النص', 'تغيير لون الحروف.'),
    _Item(Icons.format_color_fill, 'لون الخلفية', 'تظليل خلفية النص.'),
    _Item(Icons.title, 'العناوين', 'تنسيق عنوان رئيسي/فرعي (H1/H2/H3).'),
    _Item(Icons.format_list_bulleted, 'قائمة نقطية', 'قائمة بنقاط.'),
    _Item(Icons.format_list_numbered, 'قائمة رقمية', 'قائمة مرقّمة.'),
    _Item(Icons.format_quote, 'اقتباس', 'كتلة اقتباس بخطّ جانبيّ.'),
    _Item(Icons.format_align_right, 'المحاذاة', 'يمين / توسيط / يسار / ضبط.'),
    _Item(Icons.format_line_spacing, 'تباعد الأسطر', 'للأسطر المحدَّدة فقط: 1.0–2.0، بلا تسطير.'),
    _Item(Icons.format_clear, 'مسح التنسيق', 'إزالة كل التنسيق عن المحدَّد (دون حذف النص).'),
    _Item(Icons.content_paste, 'قائمة النسخ', 'إظهار/إخفاء قائمة النسخ واللصق.'),
    _Item(Icons.picture_as_pdf, 'تصدير PDF', 'حفظ الملاحظة ملف PDF منسّق.'),
    _Item(Icons.description, 'تصدير Word', 'حفظ ملف ‎.doc يفتحه Word مع التنسيق.'),
  ]),
  _Section('أدوات أعلى المحرّر', Icons.tune, _c3, [
    _Item(Icons.push_pin, 'تثبيت', 'تثبيت الملاحظة أعلى القائمة.'),
    _Item(Icons.palette_outlined, 'اللون والصفحة', 'لون الخلفية، نمط الصفحة، التسطير وتباعده.'),
    _Item(Icons.star, 'مفضّلة', 'تمييز الملاحظة كمفضّلة.'),
    _Item(Icons.alarm, 'تذكير', 'تنبيه لمرّة واحدة أو متكرّر (مع أيام الأسبوع).'),
    _Item(Icons.label_outline, 'وسوم', 'إضافة/حذف وسوم (#) للملاحظة.'),
    _Item(Icons.more_vert, 'المزيد', 'تفاصيل، حذف، أرشفة، مشاركة.'),
  ]),
  _Section('الرئيسية والتنقّل', Icons.home_outlined, _c4, [
    _Item(Icons.search, 'بحث', 'بحث فوريّ في العناوين والمحتوى.'),
    _Item(Icons.tune, 'بحث متقدّم', 'تصفية حسب النوع/التصنيف/الوسم/التاريخ.'),
    _Item(Icons.calendar_month, 'التقويم', 'عرض الملاحظات والتذكيرات حسب التاريخ.'),
    _Item(Icons.grid_view_outlined, 'تبديل العرض', 'تبديل بين شبكة وقائمة.'),
    _Item(Icons.label, 'التصنيفات', 'شرائح لتصفية الملاحظات حسب التصنيف.'),
  ]),
  _Section('اتجاه النصّ (ميزة)', Icons.format_textdirection_r_to_l, _c5, [
    _Item(Icons.subdirectory_arrow_right, 'اتجاه لكل سطر', 'كل سطر يأخذ اتجاهه من أوّل حرف لغويّ فيه.'),
    _Item(Icons.short_text, 'الرموز في بدايتها', 'تُتجاهل (- * • 1.) عند الكشف ويبقى الرمز في بداية السطر.'),
  ]),
  _Section('الأمان والخصوصية', Icons.shield_outlined, _c6, [
    _Item(Icons.lock, 'قفل الملاحظة', 'حماية الملاحظة برقم سرّي (PIN).'),
    _Item(Icons.visibility_off, 'وضع الخصوصية', 'إخفاء محتوى البطاقات وإظهار العناوين فقط.'),
    _Item(Icons.vpn_key, 'كلمات المرور', 'نوع ملاحظة لحفظ بيانات الدخول، مقفل افتراضيًّا.'),
    _Item(Icons.screenshot_monitor, 'حماية التصوير', 'منع لقطات الشاشة للملاحظات الحسّاسة.'),
  ]),
  _Section('النسخ والمزامنة', Icons.cloud_sync, _c7, [
    _Item(Icons.backup_outlined, 'نسخ احتياطي', 'حفظ/استعادة نسخة من كل ملاحظاتك.'),
    _Item(Icons.cloud, 'Google Drive', 'مزامنة حقيقية ثنائية الاتجاه بين أجهزتك.'),
    _Item(Icons.dns_outlined, 'WebDAV', 'مزامنة مع خادم خاصّ (Nextcloud وغيره).'),
    _Item(Icons.enhanced_encryption, 'تشفير E2E', 'تشفير بياناتك على جهازك قبل رفعها للسحابة.'),
    _Item(Icons.sync, 'مزامنة تلقائية', 'تتمّ عند فتح التطبيق مع شريط حالة خفيف.'),
  ]),
  _Section('أدوات وصيانة', Icons.handyman_outlined, _c8, [
    _Item(Icons.insights_outlined, 'الملخّص الأسبوعي', 'نظرة على نشاطك خلال الأسبوع.'),
    _Item(Icons.cleaning_services_outlined, 'تنظيف المذكرات', 'إزالة الفارغ/المكرّر.'),
    _Item(Icons.category_outlined, 'إدارة التصنيفات', 'إنشاء وتعديل التصنيفات وألوانها.'),
    _Item(Icons.archive_outlined, 'الأرشيف', 'الملاحظات المؤرشفة.'),
    _Item(Icons.delete_outline, 'المهملات', 'استرجاع أو حذف نهائيّ للمحذوفات.'),
    _Item(Icons.settings_outlined, 'الإعدادات', 'الخط/الحجم/التباعد واللون الافتراضي للصفحة.'),
  ]),
];
