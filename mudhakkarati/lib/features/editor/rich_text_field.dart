import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/text/line_direction.dart';
import '../settings/settings_provider.dart';
import 'voice_dictation.dart';

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
    _lastText = quill.document.toPlainText();
    // اضبط اتجاهات الأسطر فور التحميل (للملاحظات الموجودة مسبقًا) **قبل** الاشتراك
    // في تغييرات المستند، كي لا تُحسب تعديلات الاتجاه الأوّلية كتحرير من المستخدم.
    applyLineDirections(quill);
    _lastSig = _serializeWithoutDirection(); // بصمة المحتوى الابتدائية (دون اتجاه)
    // نراقب **تعديلات المستند فقط** (إدراج/حذف/تنسيق) لا تحريك المؤشّر/التحديد؛
    // فيبقى السحب والتحديد رخيصًا تمامًا (نعومة، خاصةً آخر الملاحظة)، ويُحفظ أيّ
    // تنسيق (غامق/لون/حجم) ولو لم يتغيّر النصّ — وهذا إصلاح ضياع الغامق.
    _docSub = quill.document.changes.listen((_) => _onDocChanged());
  }

  late final QuillController quill;
  final FocusNode focus = FocusNode();
  /// وحدة تمرير المحرّر — نشاركها مع خلفية الورق كي تتحرّك الأسطر مع الكتابة.
  final ScrollController scroll = ScrollController();
  final ValueChanged<String> _onChanged;
  Timer? _debounce; // تأجيل الحفظ
  bool _pending = false; // ضبط اتجاه مؤجَّل لما بعد الإطار (مجدوَل بالفعل)
  String _lastText = ''; // آخر نصّ رأيناه (لتفرقة تغيّر النص عن التنسيق)
  String _lastSig = ''; // بصمة المحتوى (دون اتجاه) لتجاهُل ضبطنا الداخلي للاتجاه
  StreamSubscription? _docSub; // اشتراك في تعديلات المستند (دون أحداث التحديد)

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

  /// يُستدعى عند كلّ **تعديل على المستند** (إدراج/حذف/تنسيق) — لا عند مجرّد تحريك
  /// المؤشّر أو التحديد (تلك لا تبثّ في `document.changes`)، فيبقى التحديد ناعمًا.
  void _onDocChanged() {
    final text = quill.document.toPlainText();
    final sig = _serializeWithoutDirection();
    if (sig == _lastSig) {
      // لا تغيّر فعليّ في المحتوى — مثل ضبطنا الداخليّ لسمة الاتجاه (تُجرَّد عند
      // الحفظ) ⇒ لا حفظ ولا إعادة حساب، فقط نُحدّث آخر نصّ.
      _lastText = text;
      return;
    }
    final textChanged = text != _lastText;
    _lastSig = sig;
    _lastText = text;
    // عند تغيّر النصّ فقط نعيد حساب اتجاه الأسطر (التنسيق لا يغيّر الاتجاه)، بعد
    // إطار الإدخال الحالي، وبشرط ألّا يُمحى «نمط معلَّق» (غامق مضبوط قبل الكتابة
    // بلا تحديد). ضبطنا للاتجاه يبثّ تغييرًا نتجاهله أعلاه (البصمة لم تتغيّر).
    if (textChanged && !_pending) {
      _pending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        if (quill.toggledStyle.attributes.isNotEmpty) return;
        applyLineDirections(quill);
      });
    }
    _scheduleSave();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _onChanged(_serializeWithoutDirection());
    });
  }

  /// يُسلسِل المستند للتخزين **دون** سمة الاتجاه (تُحسب من اللغة عند العرض).
  String _serializeWithoutDirection() {
    final ops = quill.document.toDelta().toJson();
    for (final op in ops) {
      if (op['attributes'] is Map) {
        final attrs = op['attributes'] as Map;
        attrs.remove('direction');
        if (attrs.isEmpty) op.remove('attributes');
      }
    }
    return jsonEncode(ops);
  }

  void dispose() {
    _debounce?.cancel();
    _docSub?.cancel();
    quill.dispose();
    focus.dispose();
    scroll.dispose();
  }
}

/// يضبط اتجاه **كل سطر** حسب لغته، مع **وراثة** اتجاه السطر السابق للأسطر التي
/// لا حرف لغويّ فيها بعد (فارغة/رموز/أرقام)، والافتراضي للسطر الأول **يمين**:
///
/// - سطر فيه حرف عربي ⇒ `rtl` (يمين)؛ سطر فيه حرف لاتيني ⇒ بلا سمة (المحيط LTR
///   ⇒ يسار، فالشرطة والترقيم في أوّل السطر الإنجليزي تظهر يسارًا بشكل صحيح).
/// - السطر الفارغ/الرمزي يرث اتجاه ما قبله ⇒ لا قفز عند المتابعة بنفس اللغة،
///   والملاحظة الجديدة تبدأ يمينًا (الافتراضي).
/// - يطبّق السمة على **فاصل السطر فقط** (طول 1)، ولا يستدعي updateSelection،
///   ويُغيّر فقط الأسطر التي يختلف اتجاهها الحالي عن المطلوب ⇒ المؤشّر ثابت.
void applyLineDirections(QuillController quill) {
  final text = quill.document.toPlainText();
  final doc = quill.document;
  final ops = <List<int>>[]; // [newlinePos, wantRtl(1/0)]
  var inheritedRtl = true; // الافتراضي: عربي (يمين) للسطر الأول
  var lineStart = 0;
  for (var i = 0; i < text.length; i++) {
    if (text[i] != '\n') continue;
    final lineText = text.substring(lineStart, i);
    final strong = strongLineDirection(lineText);
    final wantRtl = strong == null ? inheritedRtl : strong == TextDirection.rtl;
    inheritedRtl = wantRtl; // يرثه السطر التالي
    var cur = false;
    try {
      cur = doc.collectStyle(i, 1).attributes['direction']?.value == 'rtl';
    } catch (_) {}
    if (cur != wantRtl) ops.add([i, wantRtl ? 1 : 0]);
    lineStart = i + 1;
  }
  if (ops.isEmpty) return;
  // نُخطر بإعادة الرسم عبر آخر formatText فقط (لا updateSelection) — فلا نمسّ
  // المؤشّر ولا «النمط المعلَّق». تنسيق فاصل السطر لا يغيّر طول النص.
  for (var k = 0; k < ops.length; k++) {
    final op = ops[k];
    quill.formatText(
      op[0],
      1,
      op[1] == 1 ? Attribute.rtl : Attribute.clone(Attribute.rtl, null),
      shouldNotifyListeners: k == ops.length - 1,
    );
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
    // اتجاه محيط LTR: العربي معلّم `rtl` ⇒ يمين؛ والإنجليزي بلا سمة ⇒ يسار
    // (فالشرطة/الترقيم أوّل السطر الإنجليزي يظهران يسارًا بشكل صحيح).
    if (expand) {
      return Directionality(textDirection: TextDirection.ltr, child: editor);
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        constraints: const BoxConstraints(minHeight: 240),
        child: editor,
      ),
    );
  }
}

/// شريط أدوات التنسيق — صفّ واحد يُمرَّر أفقيًا بنعومة (يبقى ظاهرًا أثناء التحرير).
class RichTextToolbar extends StatelessWidget {
  final RichTextController controller;

  /// عند تمريره يظهر زرّ «PDF» في آخر الشريط لتصدير الملاحظة.
  final VoidCallback? onExportPdf;

  /// عند تمريره يظهر زرّ «Word» بجوار PDF لتصدير الملاحظة كمستند .doc.
  final VoidCallback? onExportWord;

  const RichTextToolbar({
    super.key,
    required this.controller,
    this.onExportPdf,
    this.onExportWord,
  });

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

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(scheme.primary.withOpacity(0.05), scheme.surface),
            scheme.surface,
          ],
        ),
        border: Border(
            top: BorderSide(color: scheme.primary.withOpacity(0.14), width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              offset: const Offset(0, -3),
              blurRadius: 12,
              spreadRadius: -2),
        ],
      ),
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
                // إملاء صوتيّ: تحدّث فيُكتب النصّ في موضع المؤشر.
                IconButton(
                  icon: const Icon(Icons.mic, size: 22),
                  tooltip: S.of(context).t('voice_typing'),
                  visualDensity: VisualDensity.compact,
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () async {
                    final text = await showVoiceDictation(context);
                    if (text == null || text.trim().isEmpty) return;
                    final sel = q.selection;
                    final docLen = q.document.length; // ينتهي دائمًا بـ \n
                    var index = sel.isValid ? sel.baseOffset : docLen - 1;
                    if (index < 0 || index > docLen - 1) index = docLen - 1;
                    final insert = '${text.trim()} ';
                    q.replaceText(index, 0, insert,
                        TextSelection.collapsed(offset: index + insert.length));
                  },
                ),
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
                // تباعد الأسطر (مضاعِف ارتفاع السطر) — يُطبَّق على **الأسطر
                // المحدّدة فقط** (أو السطر الحالي عند المؤشر) عبر سمة line-height،
                // بلا أي تسطير. القيمة 0 ⇒ إزالة التباعد الخاص (العودة للافتراضي).
                PopupMenuButton<double>(
                  tooltip: 'تباعد الأسطر (للأسطر المحدّدة)',
                  icon: const Icon(Icons.format_line_spacing, size: 22),
                  onSelected: (v) => q.formatSelection(
                    Attribute<double?>(
                        'line-height', AttributeScope.block, v == 0 ? null : v),
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 1.0, child: Text('1.0')),
                    PopupMenuItem(value: 1.25, child: Text('1.25')),
                    PopupMenuItem(value: 1.5, child: Text('1.5')),
                    PopupMenuItem(value: 1.75, child: Text('1.75')),
                    PopupMenuItem(value: 2.0, child: Text('2.0')),
                    PopupMenuItem(value: 0.0, child: Text('افتراضي')),
                  ],
                ),
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
                // تصدير PDF / Word — أيقونتان في آخر الصفّ (استخدامها قليل).
                if (onExportPdf != null)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 22),
                    tooltip: 'تصدير PDF',
                    visualDensity: VisualDensity.compact,
                    onPressed: onExportPdf,
                  ),
                if (onExportWord != null)
                  IconButton(
                    icon: const Icon(Icons.description, size: 22),
                    tooltip: 'تصدير Word‏ (.doc)',
                    visualDensity: VisualDensity.compact,
                    onPressed: onExportWord,
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

/// يبدّل سمة تنسيق مضمّنة (غامق/مائل/تسطير/شطب) بأثرٍ فوريّ مرئيّ:
/// - مع تحديد نصّ: يطبّق/يزيل السمة على المعلَّم فقط.
/// - بلا تحديد لكنّ المؤشّر داخل/ملاصق لكلمة: يطبّق/يزيل السمة على **الكلمة
///   كاملة** فيظهر الأثر فورًا (أكثر فاعلية وبديهية على الجوال).
/// - بلا تحديد ولا كلمة (سطر فارغ/مسافة): يضبط نمطًا معلَّقًا لما سيُكتب.
void _smartToggleInline(QuillController c, Attribute attr) {
  final sel = c.selection;
  if (sel.isValid && sel.isCollapsed) {
    final range = wordRangeAt(c.document.toPlainText(), sel.baseOffset);
    if (range != null) {
      final isOn = _rangeHasAttr(c, range[0], range[1] - range[0], attr);
      c.formatText(range[0], range[1] - range[0],
          isOn ? Attribute.clone(attr, null) : attr);
      return;
    }
  }
  bool isOn;
  try {
    isOn = c.getSelectionStyle().attributes.containsKey(attr.key);
  } catch (_) {
    isOn = false;
  }
  c.formatSelection(isOn ? Attribute.clone(attr, null) : attr);
}

/// نطاق الكلمة المحيطة بالموضع [offset] في [text] كـ`[start, end]`، أو `null`
/// إن لم يكن المؤشّر داخل كلمة ولا ملاصقًا لها (سطر فارغ/مسافة/فاصل سطر).
/// «حرف الكلمة» = أيّ محرف غير فراغ وغير فاصل سطر (يشمل الترقيم المُلتصق).
List<int>? wordRangeAt(String text, int offset) {
  bool isWord(int i) =>
      i >= 0 && i < text.length && text[i] != '\n' && text[i].trim().isNotEmpty;
  var start = offset;
  var end = offset;
  if (isWord(offset)) {
    while (start > 0 && isWord(start - 1)) {
      start--;
    }
    while (end < text.length && isWord(end)) {
      end++;
    }
  } else if (isWord(offset - 1)) {
    // المؤشّر ملاصق لنهاية كلمة (شائع بعد الكتابة) ⇒ نأخذ الكلمة قبله.
    while (start > 0 && isWord(start - 1)) {
      start--;
    }
  } else {
    return null;
  }
  return end > start ? [start, end] : null;
}

/// هل يحمل المدى المعطى السمةَ [attr] (لتقرير التطبيق أم الإزالة)؟
bool _rangeHasAttr(QuillController c, int start, int len, Attribute attr) {
  try {
    return c.document.collectStyle(start, len).attributes.containsKey(attr.key);
  } catch (_) {
    return false;
  }
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
    final controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    // اضبط اتجاه كل سطر حسب لغته (يشمل ملاحظات قديمة مخزّنة بلا اتجاه).
    applyLineDirections(controller);
    return controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // اتجاه محيط LTR كي يُعرض كل سطر باتجاهه (المعلّم بـ`rtl` يمينًا).
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
