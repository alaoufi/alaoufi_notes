import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// حقل نص غني (Rich Text) بتنسيق: حجم الخط، اللون، التظليل، عريض/مائل/تسطير/شطب،
/// قوائم. يعتمد على flutter_quill ويخزّن المحتوى كـ Delta JSON.
class RichTextField extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;

  const RichTextField({
    super.key,
    required this.initialContent,
    required this.onChanged,
  });

  @override
  State<RichTextField> createState() => _RichTextFieldState();
}

class _RichTextFieldState extends State<RichTextField> {
  late QuillController _controller;
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = QuillController(
      document: _documentFrom(widget.initialContent),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.addListener(_onChanged);
  }

  static Document _documentFrom(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return Document();
    // محتوى Delta JSON؟
    if (trimmed.startsWith('[')) {
      try {
        return Document.fromJson(jsonDecode(trimmed) as List);
      } catch (_) {}
    }
    // نص عادي قديم → أدرجه كما هو.
    final doc = Document();
    doc.insert(0, content);
    return doc;
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final json = jsonEncode(_controller.document.toDelta().toJson());
      widget.onChanged(json);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuillSimpleToolbar(
          controller: _controller,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showFontFamily: false,
            // حجم الخط كقائمة منسدلة مدمجة (بأحجام مخصّصة بالعربية).
            showFontSize: true,
            buttonOptions: QuillSimpleToolbarButtonOptions(
              fontSize: QuillToolbarFontSizeButtonOptions(
                items: {
                  'صغير': '12',
                  'عادي': '16',
                  'متوسط': '20',
                  'كبير': '24',
                  'أكبر': '30',
                  'عنوان': '40',
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
            // إخفاء الأزرار غير الضرورية لإبقاء الشريط بسيطًا.
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
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 220),
          child: QuillEditor.basic(
            controller: _controller,
            focusNode: _focus,
            config: const QuillEditorConfig(
              autoFocus: false,
              expands: false,
              padding: EdgeInsets.symmetric(vertical: 8),
              placeholder: 'اكتب ملاحظتك هنا...',
            ),
          ),
        ),
      ],
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
