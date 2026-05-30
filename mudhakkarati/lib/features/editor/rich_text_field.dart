import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
          // قائمة (قص/نسخ/لصق) مثبّتة أعلى الشاشة حتى لا تغطّي شريط التنسيق
          // في الأسفل عند «تحديد الكل».
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
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: QuillSimpleToolbar(
          controller: controller.quill,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showFontFamily: true,
            showFontSize: true,
            buttonOptions: QuillSimpleToolbarButtonOptions(
              fontFamily: QuillToolbarFontFamilyButtonOptions(
                items: {
                  'Cairo': 'Cairo',
                  'Tajawal': 'Tajawal',
                  'Amiri': 'Amiri',
                  'نسخ': 'Noto Naskh Arabic',
                  'كوفي': 'Reem Kufi',
                  'شهرزاد': 'Scheherazade New',
                  'مرکزی': 'Markazi Text',
                  'المصري': 'El Messiri',
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
