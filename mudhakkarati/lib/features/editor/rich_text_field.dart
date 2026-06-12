import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import '../settings/settings_provider.dart';

/// وحدة تحكّم نص غني مع تتبّع التغييرات (Delta JSON) وتأجيل الحفظ.
///
/// نفصلها عن الواجهة حتى نتمكن من وضع منطقة التحرير في الصفحة القابلة للتمرير،
/// وتثبيت شريط الأدوات أسفل الشاشة فوق لوحة المفاتيح (فلا يختفي عند التحديد).
class RichTextController {
  RichTextController(String initialContent, this._onChanged) {
    quill = QuillController(
      document: _documentFrom(initialContent),
      selection: const TextSelection.collapsed(offset: 0),
    );
    quill.addListener(_handle);
    // اتجاه تلقائي لكل سطر حسب لغته (عربي = يمين، إنجليزي = يسار).
    quill.addListener(_autoDirection);
    // وسم الأسطر العربية الموجودة مسبقًا بـ rtl وحفظها مرّة واحدة (يثبت الاتجاه).
    _normalizeDirections();
  }

  late final QuillController quill;
  final FocusNode focus = FocusNode();
  /// وحدة تمرير المحرّر — نشاركها مع خلفية الورق كي تتحرّك الأسطر مع الكتابة.
  final ScrollController scroll = ScrollController();
  final ValueChanged<String> _onChanged;
  Timer? _debounce;

  bool _settingDir = false;

  /// يضبط اتجاه السطر الحالي حسب أول حرف قويّ فيه (عربي ⇒ يمين، لاتيني ⇒ يسار).
  ///
  /// المحرّر افتراضيًّا LTR، فالأسطر اللاتينية تبقى يسارًا، والعربية نَسِمها بـ rtl.
  /// نستخدم formatSelection على السطر الحالي (آلية زرّ الاتجاه) ويُحفظ التغيير.
  void _autoDirection() {
    if (_settingDir) return;
    final sel = quill.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    try {
      final text = quill.document.toPlainText();
      if (text.isEmpty) return;
      final offset = sel.baseOffset.clamp(0, text.length);
      final start =
          offset <= 0 ? 0 : (text.lastIndexOf('\n', offset - 1) + 1);
      var end = text.indexOf('\n', offset);
      if (end < 0) end = text.length;
      if (end <= start) return; // سطر فارغ
      final dir = _detectDir(text.substring(start, end));
      if (dir == null) return; // محايد (رموز/أرقام) ⇒ لا تغيير
      // null (بلا سمة) = الافتراضي LTR.
      final cur =
          (quill.getSelectionStyle().attributes['direction']?.value) ?? 'ltr';
      if (cur == dir) return; // مضبوط بالفعل
      _settingDir = true;
      if (dir == 'rtl') {
        quill.formatSelection(Attribute.rtl);
        quill.formatSelection(Attribute.rightAlignment);
      } else {
        // إزالة سمة الاتجاه ⇒ يعود للافتراضي LTR (يسار).
        quill.formatSelection(Attribute.clone(Attribute.rtl, null));
        quill.formatSelection(Attribute.leftAlignment);
      }
    } catch (_) {
      // تجاهل أي خطأ حتى لا يتعطّل التحرير.
    } finally {
      _settingDir = false;
    }
  }

  /// وسم الأسطر العربية بـ rtl عند الفتح (للملاحظات القديمة). يتجاوز الأسطر
  /// الموسومة مسبقًا فلا يتكرّر الحفظ، فيثبت الاتجاه ولا يتغيّر عند إعادة الفتح.
  void _normalizeDirections() {
    _settingDir = true;
    try {
      final text = quill.document.toPlainText();
      var pos = 0;
      for (final line in text.split('\n')) {
        final len = line.length;
        if (len > 0 && _detectDir(line) == 'rtl') {
          String? cur;
          try {
            cur = quill.document
                .collectStyle(pos + len, 1)
                .attributes['direction']
                ?.value;
          } catch (_) {}
          if (cur != 'rtl') {
            quill.formatText(pos, len + 1, Attribute.rtl);
            quill.formatText(pos, len + 1, Attribute.rightAlignment);
          }
        }
        pos += len + 1;
      }
    } catch (_) {
    } finally {
      _settingDir = false;
    }
  }

  /// يكشف اتجاه السطر من أول حرف قويّ: 'rtl' عربي، 'ltr' لاتيني، null محايد.
  static String? _detectDir(String s) {
    for (final r in s.runes) {
      if ((r >= 0x0590 && r <= 0x08FF) ||
          (r >= 0xFB1D && r <= 0xFDFF) ||
          (r >= 0xFE70 && r <= 0xFEFF)) {
        return 'rtl';
      }
      if ((r >= 0x41 && r <= 0x5A) ||
          (r >= 0x61 && r <= 0x7A) ||
          (r >= 0xC0 && r <= 0x24F)) {
        return 'ltr';
      }
    }
    return null;
  }

  static Document _documentFrom(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return Document();
    if (trimmed.startsWith('[')) {
      try {
        return Document.fromJson(jsonDecode(trimmed) as List);
      } catch (_) {}
    }
    final doc = Document();
    doc.insert(0, content);
    return doc;
  }

  void _handle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _onChanged(jsonEncode(quill.document.toDelta().toJson()));
    });
  }

  void dispose() {
    _debounce?.cancel();
    quill.removeListener(_handle);
    quill.removeListener(_autoDirection);
    quill.dispose();
    focus.dispose();
    scroll.dispose();
  }
}

/// يبني أنماط المحرّر الافتراضية (خط المتن وحجمه وتباعد أسطره) من الإعدادات.
///
/// نضبط تباعد الأسطر داخل الفقرة وبينها إلى صفر كي يكون ارتفاع كل سطر مساويًا
/// تمامًا لـ(الحجم × التباعد) — فينتظم التسطير خلف الكتابة بدقّة.
DefaultStyles buildNoteDefaultStyles(
    BuildContext context, SettingsProvider settings,
    {double? lineHeight}) {
  final base = TextStyle(
    fontFamily: settings.noteFontFamily,
    fontSize: settings.noteFontSize,
    height: lineHeight ?? settings.noteLineHeight,
    fontWeight: settings.noteBold ? FontWeight.bold : null,
    color: DefaultTextStyle.of(context).style.color,
  );
  const hs = HorizontalSpacing(0, 0);
  const vs = VerticalSpacing(0, 0);
  final block = DefaultTextBlockStyle(base, hs, vs, vs, null);
  // مهم: في flutter_quill يَستبدل customStyles الأنماطَ الافتراضية بالكامل، فلو
  // مرّرنا فقرتنا وحدها تُفقد أنماط الغامق/المائل/العناوين/القوائم. لذا ندمج
  // تخصيصنا فوق أنماط المكتبة الافتراضية ونتجاوز فقرة المتن وتباعدها فقط.
  return DefaultStyles.getInstance(context).merge(DefaultStyles(
    paragraph: block,
    lineHeightNormal: block,
    bold: const TextStyle(fontWeight: FontWeight.bold),
    italic: const TextStyle(fontStyle: FontStyle.italic),
    underline: const TextStyle(decoration: TextDecoration.underline),
    strikeThrough: const TextStyle(decoration: TextDecoration.lineThrough),
  ));
}

/// ارتفاع سطر المتن بالبكسل (لمطابقة تباعد التسطير مع الكتابة).
/// [lineHeight] يتجاوز التباعد العام (لتباعد خاص بالملاحظة).
double noteLineGap(SettingsProvider settings, {double? lineHeight}) =>
    settings.noteFontSize * (lineHeight ?? settings.noteLineHeight);

/// حجم خطّ التسطير: يعيد الحجم الموحّد للنص إن كانت الصفحة بحجم واحد، أو
/// `null` إذا اختلفت الأحجام داخل الملاحظة (عندها نُلغي التسطير كليًّا لأنه لا
/// يمكن لخطوط ثابتة المسافة أن تحاذي أسطرًا مختلفة الارتفاع).
///
/// النص بلا حجم صريح يُحسب على [fallback] (الحجم الأساسي). فلو كبّر المستخدم أو
/// صغّر خطّ الصفحة كاملةً انضبط التسطير معه بدقّة؛ ولو خلط أحجامًا اختفت الخطوط.
double? noteRulingFontSize(QuillController controller, double fallback) {
  final sizes = <double>{};
  for (final op in controller.document.toDelta().toList()) {
    final data = op.data;
    if (data is! String) continue;
    if (data.replaceAll('\n', '').isEmpty) continue;
    var size = fallback;
    final raw = op.attributes?['size'];
    if (raw != null) {
      final parsed = double.tryParse(raw.toString());
      if (parsed != null && parsed > 0) size = parsed;
    }
    sizes.add(size);
    if (sizes.length > 1) return null; // أحجام مختلفة ⇒ نُلغي التسطير
  }
  return sizes.isEmpty ? fallback : sizes.first;
}

/// منطقة تحرير النص الغني (بلا شريط أدوات — يوضع الشريط مثبّتًا في الأسفل).
///
/// [expand] = true يجعل المحرّر يملأ مساحته ويمرّر داخليًا (مع تمرير الـ viewport
/// = أداء أفضل بكثير للمستندات الكبيرة لأنه يعرض الجزء المرئي فقط).
class RichTextEditorBody extends StatelessWidget {
  final RichTextController controller;
  final bool expand;

  /// تباعد أسطر خاص بالملاحظة (يتجاوز الافتراضي العام). null = العام.
  final double? lineHeight;
  const RichTextEditorBody(
      {super.key,
      required this.controller,
      this.expand = false,
      this.lineHeight});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final hide = settings.hideSelectionMenu;
    final editor = QuillEditor.basic(
      controller: controller.quill,
      focusNode: controller.focus,
      scrollController: controller.scroll,
      config: QuillEditorConfig(
        autoFocus: false,
        expands: expand,
        scrollable: expand,
        padding: const EdgeInsets.symmetric(vertical: 8),
        customStyles:
            buildNoteDefaultStyles(context, settings, lineHeight: lineHeight),
        // مكبّر يظهر أثناء سحب مقبض التحديد ⇒ تحديد الكلمات أدقّ بكثير.
        quillMagnifierBuilder: defaultQuillMagnifierBuilder,
        placeholder: 'اكتب ملاحظتك هنا...',
        // نُبقي باني القائمة غير فارغ دائمًا (تجنّبًا لتعطّل المكتبة عند
        // التبديل المباشر). عند الإخفاء نعيد عنصرًا فارغًا فلا تظهر القائمة،
        // وعند الإظهار نثبّتها أعلى الشاشة كي لا تغطّي شريط التنسيق.
        contextMenuBuilder: (context, state) {
          if (hide) return const SizedBox.shrink();
          final top = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
          final anchor = Offset(MediaQuery.of(context).size.width / 2, top);
          return TextFieldTapRegion(
            child: AdaptiveTextSelectionToolbar.buttonItems(
              anchors: TextSelectionToolbarAnchors(primaryAnchor: anchor),
              buttonItems: state.contextMenuButtonItems,
            ),
          );
        },
      ),
    );
    // الاتجاه الافتراضي للمحرّر LTR: الأسطر اللاتينية يسارًا، والعربية تُوسَم
    // rtl تلقائيًّا فتنتقل يمينًا (مع موضع مربع الاختيار في الجهة الصحيحة).
    final body = Directionality(textDirection: TextDirection.ltr, child: editor);
    if (expand) return body;
    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      child: body,
    );
  }
}

/// شريط أدوات التنسيق — صفّ واحد يُمرَّر أفقيًا بنعومة (يبقى ظاهرًا أثناء التحرير).
class RichTextToolbar extends StatelessWidget {
  final RichTextController controller;

  /// عند تمريره يظهر زرّ «PDF» بارز في بداية الشريط لتصدير الملاحظة.
  final VoidCallback? onExportPdf;
  const RichTextToolbar(
      {super.key, required this.controller, this.onExportPdf});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final hide = settings.hideSelectionMenu;
    final scheme = Theme.of(context).colorScheme;
    final q = controller.quill;

    // زرّ تنسيق ذكي: مؤشر داخل كلمة بلا تحديد ⇒ يطبّقه على الكلمة كاملة.
    Widget fmtBtn(IconData icon, String tip, Attribute attr) => IconButton(
          icon: Icon(icon, size: 22),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          onPressed: () => _smartToggleInline(q, attr),
        );

    // زرّ محاذاة: يطبّق محاذاة السطر الحالي (يمين/وسط/يسار/ضبط).
    Widget alignBtn(IconData icon, String tip, Attribute attr) => IconButton(
          icon: Icon(icon, size: 22),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          onPressed: () => q.formatSelection(attr),
        );

    Widget sep() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: SizedBox(
              height: 26, child: VerticalDivider(width: 1, thickness: 1)),
        );

    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        // صفّ واحد قابل للتمرير الأفقي بنعومة (يمين/يسار).
        child: SizedBox(
          height: 54,
          child: ScrollConfiguration(
            // تمرير سلس باللمس + بالماوس/اللوحة.
            behavior: const _SmoothToolbarScrollBehavior(),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                // التراجع/الإعادة في أول الصفّ.
                QuillToolbarHistoryButton(controller: q, isUndo: true),
                QuillToolbarHistoryButton(controller: q, isUndo: false),
                sep(),
                // الخط + الحجم.
                QuillToolbarFontFamilyButton(
                  controller: q,
                  options: const QuillToolbarFontFamilyButtonOptions(
                      items: _fontFamilies),
                ),
                QuillToolbarFontSizeButton(
                  controller: q,
                  options:
                      const QuillToolbarFontSizeButtonOptions(items: _fontSizes),
                ),
                // غامق/مائل/تسطير/شطب (تنسيق ذكي للكلمة كاملة).
                fmtBtn(Icons.format_bold, 'غامق', Attribute.bold),
                fmtBtn(Icons.format_italic, 'مائل', Attribute.italic),
                fmtBtn(Icons.format_underline, 'تسطير', Attribute.underline),
                fmtBtn(Icons.format_strikethrough, 'شطب',
                    Attribute.strikeThrough),
                sep(),
                // الألوان (نص + خلفية).
                QuillToolbarColorButton(controller: q, isBackground: false),
                QuillToolbarColorButton(controller: q, isBackground: true),
                sep(),
                // العناوين + القوائم + الاقتباس.
                QuillToolbarSelectHeaderStyleDropdownButton(controller: q),
                QuillToolbarToggleStyleButton(
                    controller: q, attribute: Attribute.ul),
                QuillToolbarToggleStyleButton(
                    controller: q, attribute: Attribute.ol),
                QuillToolbarToggleCheckListButton(controller: q),
                QuillToolbarToggleStyleButton(
                    controller: q, attribute: Attribute.blockQuote),
                sep(),
                // المحاذاة (يمين/وسط/يسار/ضبط).
                alignBtn(Icons.format_align_right, 'محاذاة لليمين',
                    Attribute.rightAlignment),
                alignBtn(Icons.format_align_center, 'توسيط',
                    Attribute.centerAlignment),
                alignBtn(Icons.format_align_left, 'محاذاة لليسار',
                    Attribute.leftAlignment),
                alignBtn(Icons.format_align_justify, 'ضبط',
                    Attribute.justifyAlignment),
                sep(),
                // مسح التنسيق.
                QuillToolbarClearFormatButton(controller: q),
                // إظهار/إخفاء قائمة النسخ واللصق.
                IconButton(
                  icon: Icon(hide
                      ? Icons.content_paste_off_outlined
                      : Icons.content_paste_outlined),
                  tooltip: hide
                      ? 'إظهار قائمة النسخ/اللصق'
                      : 'إخفاء قائمة النسخ/اللصق',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => settings.setHideSelectionMenu(!hide),
                ),
                // تصدير PDF — أيقونة في آخر الصفّ (استخدامها قليل).
                if (onExportPdf != null)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 22),
                    tooltip: 'تصدير PDF',
                    visualDensity: VisualDensity.compact,
                    onPressed: onExportPdf,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // خرائط الخطوط والأحجام (تُستخدم في أزرار الصف الأول).
  static const Map<String, String> _fontFamilies = {
    'Cairo': 'Cairo',
    'Tajawal': 'Tajawal',
    'Almarai': 'Almarai',
    'IBM Plex': 'IBM Plex Sans Arabic',
    'Readex': 'Readex Pro',
    'Mada': 'Mada',
    'Changa': 'Changa',
    'Vazirmatn': 'Vazirmatn',
    'المصري': 'El Messiri',
    'مرکزی': 'Markazi Text',
    'ليمونادة': 'Lemonada',
    'هرمتان': 'Harmattan',
    'كوفي': 'Reem Kufi',
    'كُفام': 'Kufam',
    'مرحى': 'Marhey',
    'نسخ': 'Noto Naskh Arabic',
    'أميري': 'Amiri',
    'شهرزاد': 'Scheherazade New',
    'رقعة': 'Aref Ruqaa',
    'لاله‌زار': 'Lalezar',
    'ركّاس': 'Rakkas',
    'جمهورية': 'Jomhuria',
    'كلزار': 'Gulzar',
    'قاهري': 'Qahiri',
    'نوتو كوفي': 'Noto Kufi Arabic',
    'نوتو سانس': 'Noto Sans Arabic',
    'روبيك': 'Rubik',
    'بالو': 'Baloo Bhaijaan 2',
    'لطيف': 'Lateef',
    'ميرزا': 'Mirza',
    'كتيبة': 'Katibeh',
    'القلمي': 'Alkalami',
    'رقعة حبر': 'Aref Ruqaa Ink',
    'نسخ قرآني': 'Amiri Quran',
    'نستعليق': 'Noto Nastaliq Urdu',
    'مسح': 'Clear',
  };

  static const Map<String, String> _fontSizes = {
    '10': '10',
    '12': '12',
    '14': '14',
    '16': '16',
    '18': '18',
    '20': '20',
    '24': '24',
    '28': '28',
    '32': '32',
    '40': '40',
    '48': '48',
    '64': '64',
    'مسح': '0',
  };
}

/// سلوك تمرير يسمح بالسحب الأفقي للشريط باللمس والماوس واللوحة (تمرير ناعم).
class _SmoothToolbarScrollBehavior extends MaterialScrollBehavior {
  const _SmoothToolbarScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// يبدّل سمة تنسيق مضمّنة «بذكاء»:
/// - مع تحديد نصّ: يطبّقها على التحديد (السلوك المعتاد).
/// - مؤشر داخل كلمة بلا تحديد: يطبّقها على الكلمة كاملة (مثل Word) —
///   كان الضغط سابقًا يضبط تنسيق الكتابة القادمة فقط فيبدو أن الزرّ لا يعمل.
/// - مؤشر على حافة كلمة/سطر فارغ: يضبط تنسيق ما سيُكتب بعده.
void _smartToggleInline(QuillController c, Attribute attr) {
  // حالة التفعيل الحالية (محسوبة بأمان وقت الضغط).
  bool isOn;
  try {
    isOn = c.getSelectionStyle().attributes.containsKey(attr.key);
  } catch (_) {
    isOn = false;
  }
  final toggle = isOn ? Attribute.clone(attr, null) : attr;
  final sel = c.selection;
  if (sel.isValid && sel.isCollapsed) {
    final text = c.document.toPlainText();
    bool isWord(int i) =>
        i >= 0 && i < text.length && text[i].trim().isNotEmpty;
    final caret = sel.baseOffset;
    // المؤشر ملاصق لكلمة من أي جهة (داخلها أو عند حافتها) ⇒ نسّق الكلمة كاملة.
    if (isWord(caret - 1) || isWord(caret)) {
      var start = caret, end = caret;
      while (isWord(start - 1)) {
        start--;
      }
      while (isWord(end)) {
        end++;
      }
      if (end > start) {
        c.formatText(start, end - start, toggle);
        return;
      }
    }
  }
  c.formatSelection(toggle);
}

/// يحوّل محتوى ملاحظة (Delta JSON أو نص عادي) إلى نص صريح للمعاينة في البطاقة.
String richToPlainText(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('[')) {
    try {
      final doc = Document.fromJson(jsonDecode(trimmed) as List);
      return doc.toPlainText().trim();
    } catch (_) {
      return content;
    }
  }
  return content;
}

/// عارض نص غني للقراءة فقط (يعرض تنسيق Delta، أو نصًّا عاديًا إن لم يكن Delta).
class RichTextViewer extends StatefulWidget {
  final String content;
  const RichTextViewer({super.key, required this.content});

  @override
  State<RichTextViewer> createState() => _RichTextViewerState();
}

class _RichTextViewerState extends State<RichTextViewer> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _build();
  }

  @override
  void didUpdateWidget(covariant RichTextViewer old) {
    super.didUpdateWidget(old);
    if (old.content != widget.content) {
      _controller.dispose();
      _controller = _build();
    }
  }

  QuillController _build() {
    final trimmed = widget.content.trim();
    Document doc;
    if (trimmed.startsWith('[')) {
      try {
        doc = Document.fromJson(jsonDecode(trimmed) as List);
      } catch (_) {
        doc = Document()..insert(0, widget.content);
      }
    } else {
      doc = Document();
      if (trimmed.isNotEmpty) doc.insert(0, widget.content);
    }
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: QuillEditor.basic(
        controller: _controller,
        config: const QuillEditorConfig(
          showCursor: false,
          expands: false,
          padding: EdgeInsets.zero,
          autoFocus: false,
        ),
      ),
    );
  }
}
