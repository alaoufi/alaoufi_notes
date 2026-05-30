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
  }
}

/// منطقة تحرير النص الغني (بلا شريط أدوات — يوضع الشريط مثبّتًا في الأسفل).
class RichTextEditorBody extends StatelessWidget {
  final RichTextController controller;
  const RichTextEditorBody({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final hide = context.watch<SettingsProvider>().hideSelectionMenu;
    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      child: QuillEditor.basic(
        controller: controller.quill,
        focusNode: controller.focus,
        config: QuillEditorConfig(
          autoFocus: false,
          expands: false,
          padding: const EdgeInsets.symmetric(vertical: 8),
          placeholder: 'اكتب ملاحظتك هنا...',
          // عند تفعيل الإخفاء: نوقف شريط (نسخ/لصق/تحديد) كليًّا فلا يغطّي
          // أدوات الخط والحجم. لا يزال بإمكانك تحديد النص وتنسيقه.
          enableSelectionToolbar: !hide,
          // عند الإظهار: نثبّت القائمة أعلى الشاشة كي لا تغطّي شريط التنسيق.
          contextMenuBuilder: (context, state) {
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
      ),
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
            buttonOptions: const QuillSimpleToolbarButtonOptions(
              fontFamily: QuillToolbarFontFamilyButtonOptions(
                items: {
                  'Cairo': 'Cairo',
                  'Tajawal': 'Tajawal',
                  'Almarai': 'Almarai',
                  'IBM Plex': 'IBM Plex Sans Arabic',
                  'Readex': 'Readex Pro',
                  'Changa': 'Changa',
                  'Vazirmatn': 'Vazirmatn',
                  'المصري': 'El Messiri',
                  'مرکزی': 'Markazi Text',
                  'كوفي': 'Reem Kufi',
                  'أميري': 'Amiri',
                  'نسخ': 'Noto Naskh Arabic',
                  'شهرزاد': 'Scheherazade New',
                  'رقعة': 'Aref Ruqaa',
                  'لاله‌زار': 'Lalezar',
                  'مسح': 'Clear',
                },
              ),
              fontSize: QuillToolbarFontSizeButtonOptions(
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
