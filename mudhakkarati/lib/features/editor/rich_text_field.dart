import 'dart:async';
import 'dart:convert';

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
  }

  late final QuillController quill;
  final FocusNode focus = FocusNode();
  /// وحدة تمرير المحرّر — نشاركها مع خلفية الورق كي تتحرّك الأسطر مع الكتابة.
  final ScrollController scroll = ScrollController();
  final ValueChanged<String> _onChanged;
  Timer? _debounce;

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
    if (expand) return editor;
    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      child: editor,
    );
  }
}

/// شريط أدوات التنسيق — يُوضع مثبّتًا أسفل الشاشة (يبقى ظاهرًا أثناء التحرير).
class RichTextToolbar extends StatelessWidget {
  final RichTextController controller;
  const RichTextToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final hide = settings.hideSelectionMenu;
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: QuillSimpleToolbar(
          controller: controller.quill,
          config: QuillSimpleToolbarConfig(
            // صفّ واحد مدمج قابل للسحب الأفقي بسلاسة — يوفّر مساحة الصفحة.
            multiRowsDisplay: false,
            showFontFamily: true,
            showFontSize: true,
            // زر سريع لإخفاء/إظهار قائمة (نسخ/لصق) أثناء التحرير.
            customButtons: [
              QuillToolbarCustomButtonOptions(
                icon: Icon(hide
                    ? Icons.content_paste_off_outlined
                    : Icons.content_paste_outlined),
                tooltip: hide ? 'إظهار قائمة النسخ/اللصق' : 'إخفاء قائمة النسخ/اللصق',
                onPressed: () => settings.setHideSelectionMenu(!hide),
              ),
            ],
            buttonOptions: QuillSimpleToolbarButtonOptions(
              // أزرار تنسيق «ذكية»: المؤشر داخل كلمة (بلا تحديد) يطبّق التنسيق
              // على الكلمة كاملة — كما في برامج التحرير الاحترافية.
              bold: _smartToggleOptions(
                  controller.quill, Icons.format_bold, Attribute.bold),
              italic: _smartToggleOptions(
                  controller.quill, Icons.format_italic, Attribute.italic),
              underLine: _smartToggleOptions(
                  controller.quill, Icons.format_underline, Attribute.underline),
              strikeThrough: _smartToggleOptions(controller.quill,
                  Icons.format_strikethrough, Attribute.strikeThrough),
              fontFamily: const QuillToolbarFontFamilyButtonOptions(
                items: {
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
                },
              ),
              fontSize: const QuillToolbarFontSizeButtonOptions(
                items: {
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
                },
              ),
            ),
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: true,
            showColorButton: true,
            showBackgroundColorButton: true,
            showLineHeightButton: true,
            showClearFormat: true,
            showListBullets: true,
            showListNumbers: true,
            showListCheck: true,
            showQuote: true,
            showSmallButton: false,
            showInlineCode: false,
            showCodeBlock: false,
            showIndent: false,
            showLink: false,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            showHeaderStyle: true,
            showAlignmentButtons: true,
            showDirection: false,
            showDividers: true,
            showUndo: true,
            showRedo: true,
          ),
        ),
      ),
    );
  }
}

/// يبدّل سمة تنسيق مضمّنة «بذكاء»:
/// - مع تحديد نصّ: يطبّقها على التحديد (السلوك المعتاد).
/// - مؤشر داخل كلمة بلا تحديد: يطبّقها على الكلمة كاملة (مثل Word) —
///   كان الضغط سابقًا يضبط تنسيق الكتابة القادمة فقط فيبدو أن الزرّ لا يعمل.
/// - مؤشر على حافة كلمة/سطر فارغ: يضبط تنسيق ما سيُكتب بعده.
void _smartToggleInline(QuillController c, Attribute attr, bool isOn) {
  final sel = c.selection;
  if (sel.isValid && sel.isCollapsed) {
    final text = c.document.toPlainText();
    bool isWord(int i) =>
        i >= 0 && i < text.length && text[i].trim().isNotEmpty;
    final caret = sel.baseOffset;
    if (isWord(caret - 1) && isWord(caret)) {
      var start = caret, end = caret;
      while (isWord(start - 1)) {
        start--;
      }
      while (isWord(end)) {
        end++;
      }
      c.formatText(
          start, end - start, isOn ? Attribute.clone(attr, null) : attr);
      return;
    }
  }
  c.formatSelection(isOn ? Attribute.clone(attr, null) : attr);
}

/// زرّ تبديل مخصّص يستخدم [_smartToggleInline] ويُظهر حالة التفعيل بوضوح.
QuillToolbarToggleStyleButtonOptions _smartToggleOptions(
    QuillController quill, IconData icon, Attribute attr) {
  return QuillToolbarToggleStyleButtonOptions(
    childBuilder: (options, extra) {
      final toggled = extra.isToggled;
      final scheme = Theme.of(extra.context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(icon,
              size: 23, color: toggled ? scheme.onPrimary : null),
          style: IconButton.styleFrom(
            backgroundColor: toggled ? scheme.primary : null,
          ),
          onPressed: () => _smartToggleInline(quill, attr, toggled),
        ),
      );
    },
  );
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
    return QuillEditor.basic(
      controller: _controller,
      config: const QuillEditorConfig(
        showCursor: false,
        expands: false,
        padding: EdgeInsets.zero,
        autoFocus: false,
      ),
    );
  }
}
