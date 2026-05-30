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
    // لتحديث رقم حجم الخط المعروض عند تحريك المؤشّر.
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int _currentSize() {
    final v = _controller.getSelectionStyle().attributes['size']?.value;
    return int.tryParse(v?.toString() ?? '') ?? 16;
  }

  void _setSize(int size) {
    final clamped = size.clamp(8, 96);
    _controller.formatSelection(
        Attribute('size', AttributeScope.inline, '$clamped'));
    if (mounted) setState(() {});
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
    _controller.removeListener(_refresh);
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
            showFontSize: false,
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
            showDividers: false,
            showUndo: true,
            showRedo: true,
          ),
        ),
        _fontSizeBar(context),
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

  /// متحكّم رقمي بحجم الخط (− 16 +) كما في تطبيقات المذكّرات الاحترافية.
  Widget _fontSizeBar(BuildContext context) {
    final size = _currentSize();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.format_size, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove),
                  tooltip: 'تصغير',
                  onPressed: () => _setSize(size - 2),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$size',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add),
                  tooltip: 'تكبير',
                  onPressed: () => _setSize(size + 2),
                ),
              ],
            ),
          ),
          const Spacer(),
          // أزرار سريعة لأحجام شائعة.
          for (final s in const [14, 18, 24, 32])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ActionChip(
                label: Text('$s'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _setSize(s),
              ),
            ),
        ],
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
