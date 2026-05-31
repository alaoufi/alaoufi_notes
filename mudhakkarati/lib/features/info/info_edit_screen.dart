import 'package:flutter/material.dart';

import '../../data/models/info_entry.dart';
import '../../data/repositories/info_repository.dart';

/// شاشة إضافة/تعديل عنصر في قاعدة المعلومات العامة.
class InfoEditScreen extends StatefulWidget {
  final InfoEntry? entry;
  const InfoEditScreen({super.key, this.entry});

  @override
  State<InfoEditScreen> createState() => _InfoEditScreenState();
}

class _InfoEditScreenState extends State<InfoEditScreen> {
  final _repo = InfoRepository();
  late final TextEditingController _main;
  late final TextEditingController _sub;
  late final TextEditingController _topic;
  late final TextEditingController _brief;
  late final TextEditingController _detail;
  late final TextEditingController _notes;
  late final TextEditingController _source;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _main = TextEditingController(text: e?.mainSpecialty ?? '');
    _sub = TextEditingController(text: e?.subSpecialty ?? '');
    _topic = TextEditingController(text: e?.topic ?? '');
    _brief = TextEditingController(text: e?.brief ?? '');
    _detail = TextEditingController(text: e?.detail ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _source = TextEditingController(text: e?.source ?? '');
  }

  @override
  void dispose() {
    for (final c in [_main, _sub, _topic, _brief, _detail, _notes, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_topic.text.trim().isEmpty && _brief.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل الموضوع أو المختصر على الأقل')));
      return;
    }
    setState(() => _saving = true);
    final base = (widget.entry ?? InfoEntry(createdAt: DateTime.now()));
    final entry = base.copyWith(
      mainSpecialty: _main.text.trim(),
      subSpecialty: _sub.text.trim(),
      topic: _topic.text.trim(),
      brief: _brief.text.trim(),
      detail: _detail.text.trim(),
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
      {int maxLines = 1, String? hint}) {
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
          hintText: hint,
          prefixIcon: Icon(icon),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل معلومة' : 'إضافة معلومة'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_main, 'التخصص الرئيسي', Icons.account_tree_outlined),
            _field(_sub, 'التخصص الفرعي', Icons.subdirectory_arrow_left),
            _field(_topic, 'الموضوع', Icons.title),
            _field(_brief, 'المختصر', Icons.short_text, maxLines: 3),
            _field(_detail, 'التفصيل', Icons.notes, maxLines: 8),
            _field(_notes, 'ملاحظات', Icons.sticky_note_2_outlined, maxLines: 4),
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
    );
  }
}
