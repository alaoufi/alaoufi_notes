import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/models/info_entry.dart';
import '../../data/repositories/info_repository.dart';
import '../../widgets/ui_kit.dart';
import '../editor/rich_text_field.dart';

/// شاشة إضافة/تعديل عنصر في قاعدة المعلومات العامة — تصميم بطاقات عصري.
class InfoEditScreen extends StatefulWidget {
  final InfoEntry? entry;
  final String? initialMain;
  final String? initialSub;
  const InfoEditScreen(
      {super.key, this.entry, this.initialMain, this.initialSub});

  @override
  State<InfoEditScreen> createState() => _InfoEditScreenState();
}

class _InfoEditScreenState extends State<InfoEditScreen> {
  final _repo = InfoRepository();
  late final TextEditingController _main;
  late final TextEditingController _sub;
  late final TextEditingController _topic;
  late final TextEditingController _brief;
  late final RichTextController _detail; // محرّر نص غني مع تنسيق
  late final TextEditingController _notes;
  late final TextEditingController _source;
  bool _saving = false;
  bool _showToolbar = false;
  List<InfoEntry> _all = []; // لاقتراح التخصصات الموجودة في قائمة الاختيار

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _main = TextEditingController(
        text: e?.mainSpecialty ?? widget.initialMain ?? '');
    _sub =
        TextEditingController(text: e?.subSpecialty ?? widget.initialSub ?? '');
    _topic = TextEditingController(text: e?.topic ?? '');
    _brief = TextEditingController(text: e?.brief ?? '');
    _detail = RichTextController(e?.detail ?? '', (_) {});
    _notes = TextEditingController(text: e?.notes ?? '');
    _source = TextEditingController(text: e?.source ?? '');
    _detail.focus.addListener(() {
      if (mounted) setState(() => _showToolbar = _detail.focus.hasFocus);
    });
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final all = await _repo.getAll();
    if (mounted) setState(() => _all = all);
  }

  /// قائمة التخصصات الرئيسية الموجودة (للاختيار من قائمة بدل التكرار).
  List<String> get _mainOptions => {
        for (final e in _all)
          if (e.mainSpecialty.trim().isNotEmpty) e.mainSpecialty.trim()
      }.toList()
        ..sort();

  /// التخصصات الفرعية (ضمن الرئيسي المختار إن وُجد، وإلا كلّها).
  List<String> get _subOptions {
    final main = _main.text.trim();
    return {
      for (final e in _all)
        if (e.subSpecialty.trim().isNotEmpty &&
            (main.isEmpty || e.mainSpecialty.trim() == main))
          e.subSpecialty.trim()
    }.toList()
      ..sort();
  }

  /// يعرض قائمة قابلة للبحث لاختيار قيمة موجودة (أو الإبقاء على الكتابة الحرّة).
  Future<void> _pickFromList(
      TextEditingController c, String title, List<String> options) async {
    if (options.isEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    var query = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = options
              .where((o) => o.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'بحث…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setSheet(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final o in filtered)
                          ListTile(
                            dense: true,
                            leading:
                                Icon(Icons.label_outline, color: scheme.primary),
                            title: Text(o),
                            onTap: () => Navigator.pop(ctx, o),
                          ),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('لا توجد عناصر مطابقة'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked != null) setState(() => c.text = picked);
  }

  @override
  void dispose() {
    for (final c in [_main, _sub, _topic, _brief, _notes, _source]) {
      c.dispose();
    }
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_topic.text.trim().isEmpty && _brief.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل الموضوع أو الملخص على الأقل')));
      return;
    }
    setState(() => _saving = true);
    try {
      // التفصيل: نخزّن Delta إن كان فيه نص، وإلا فارغًا.
      final detailJson = jsonEncode(_detail.quill.document.toDelta().toJson());
      final detail = richToPlainText(detailJson).isEmpty ? '' : detailJson;

      final base = (widget.entry ?? InfoEntry(createdAt: DateTime.now()));
      final entry = base.copyWith(
        mainSpecialty: _main.text.trim(),
        subSpecialty: _sub.text.trim(),
        topic: _topic.text.trim(),
        brief: _brief.text.trim(),
        detail: detail,
        notes: _notes.text.trim(),
        source: _source.text.trim(),
      );
      if (entry.id == null) {
        await _repo.insert(entry);
      } else {
        await _repo.update(entry);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ ✓')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {int maxLines = 1, VoidCallback? onPickList}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 2 : 1,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          alignLabelWithHint: true,
          // زرّ «اختيار من قائمة» للتخصصات الموجودة.
          suffixIcon: onPickList == null
              ? null
              : IconButton(
                  tooltip: 'اختيار من قائمة',
                  icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                  onPressed: onPickList,
                ),
        ),
      ),
    );
  }

  /// بطاقة قسم عصرية (أيقونة متدرّجة + عنوان + حقول).
  Widget _card(String title, IconData icon, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GradientIcon(icon, size: 36),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: scheme.primary)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _detailField() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _showToolbar ? scheme.primary : scheme.outlineVariant,
          width: _showToolbar ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notes, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text('التفصيل',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.primary)),
            const Spacer(),
            Text('بأدوات تنسيق',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor)),
          ]),
          const Divider(height: 14),
          RichTextEditorBody(controller: _detail),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    final kb = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      // مهم: يمنع تضاعف حساب ارتفاع الكيبورد مع شريط التنسيق (سبب التداخل).
      resizeToAvoidBottomInset: false,
      appBar: gradientAppBar(
          context, editing ? 'تعديل معلومة' : 'إضافة معلومة', actions: [
        IconButton(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          tooltip: 'حفظ',
        ),
      ]),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 24),
                children: [
                  _card('التصنيف', Icons.account_tree_outlined, [
                    _field(_main, 'التخصص الرئيسي',
                        Icons.account_tree_outlined,
                        onPickList: () => _pickFromList(
                            _main, 'التخصص الرئيسي', _mainOptions)),
                    _field(_sub, 'التخصص الفرعي',
                        Icons.subdirectory_arrow_left,
                        onPickList: () =>
                            _pickFromList(_sub, 'التخصص الفرعي', _subOptions)),
                  ]),
                  _card('المحتوى', Icons.article_outlined, [
                    _field(_topic, 'الموضوع', Icons.title),
                    _field(_brief, 'الملخص', Icons.short_text, maxLines: 3),
                    _detailField(),
                  ]),
                  _card('معلومات إضافية', Icons.more_horiz, [
                    _field(_notes, 'ملاحظات', Icons.sticky_note_2_outlined,
                        maxLines: 4),
                    _field(_source, 'المصدر', Icons.link),
                  ]),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                    ),
                  ),
                ],
              ),
            ),
            // شريط التنسيق فوق لوحة المفاتيح عند تحرير «التفصيل».
            if (_showToolbar)
              Padding(
                padding: EdgeInsets.only(bottom: kb),
                child: RichTextToolbar(controller: _detail),
              ),
          ],
        ),
      ),
    );
  }
}
