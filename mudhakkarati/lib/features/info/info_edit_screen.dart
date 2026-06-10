import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/models/info_entry.dart';
import '../../data/repositories/info_repository.dart';
import '../../widgets/ui_kit.dart';
import '../editor/rich_text_field.dart';

/// شاشة إضافة/تعديل عنصر في قاعدة المعلومات العامة.
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
          const SnackBar(content: Text('أدخل الموضوع أو المختصر على الأقل')));
      return;
    }
    setState(() => _saving = true);
    // التفصيل: نخزّن Delta إن كان فيه نص، وإلا فارغًا.
    final detailJson =
        jsonEncode(_detail.quill.document.toDelta().toJson());
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
    if (mounted) Navigator.pop(context, true);
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
        ),
      ),
    );
  }

  Widget _detailField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _showToolbar ? scheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notes, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text('التفصيل',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: scheme.primary)),
            const Spacer(),
            Text('بأدوات تنسيق',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor)),
          ]),
          const Divider(),
          RichTextEditorBody(controller: _detail),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    return Scaffold(
      appBar: gradientAppBar(
          context, editing ? 'تعديل معلومة' : 'إضافة معلومة', actions: [
        IconButton(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check),
          tooltip: 'حفظ',
        ),
      ]),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _field(_main, 'التخصص الرئيسي', Icons.account_tree_outlined),
                  _field(_sub, 'التخصص الفرعي', Icons.subdirectory_arrow_left),
                  _field(_topic, 'الموضوع', Icons.title),
                  _field(_brief, 'المختصر', Icons.short_text, maxLines: 3),
                  _detailField(context),
                  _field(_notes, 'ملاحظات', Icons.sticky_note_2_outlined,
                      maxLines: 4),
                  _field(_source, 'المصدر', Icons.link),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ'),
                  ),
                ],
              ),
            ),
            // شريط التنسيق يظهر فوق لوحة المفاتيح عند تحرير «التفصيل».
            if (_showToolbar)
              Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: RichTextToolbar(controller: _detail),
              ),
          ],
        ),
      ),
    );
  }
}
