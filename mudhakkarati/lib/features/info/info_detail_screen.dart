import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/info_entry.dart';
import '../../data/repositories/info_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/ui_kit.dart';
import '../editor/rich_text_field.dart';
import 'info_edit_screen.dart';
import 'info_list_screen.dart';

/// عرض احترافي لعنصر معلومة (مع نسخ/تعديل/حذف).
class InfoDetailScreen extends StatefulWidget {
  final InfoEntry entry;
  const InfoDetailScreen({super.key, required this.entry});

  @override
  State<InfoDetailScreen> createState() => _InfoDetailScreenState();
}

class _InfoDetailScreenState extends State<InfoDetailScreen> {
  final _repo = InfoRepository();
  late InfoEntry _e = widget.entry;

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InfoEditScreen(entry: _e)),
    );
    if (changed == true) {
      // أعد تحميل أحدث نسخة (نبقى في العرض مع المحتوى المحدَّث).
      final all = await _repo.getAll();
      final found = all.where((x) => x.id == _e.id);
      if (found.isNotEmpty && mounted) setState(() => _e = found.first);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(context,
        title: 'حذف المعلومة؟',
        message: 'سيُحذف هذا العنصر نهائيًا بلا إمكانية استرجاع.',
        icon: Icons.delete_forever);
    if (ok && _e.id != null) {
      await _repo.delete(_e.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  void _copyAll() {
    final b = StringBuffer();
    void add(String label, String v) {
      if (v.trim().isNotEmpty) b.writeln('$label: $v');
    }

    add('التخصص الرئيسي', _e.mainSpecialty);
    add('التخصص الفرعي', _e.subSpecialty);
    add('الموضوع', _e.topic);
    add('المختصر', _e.brief);
    add('التفصيل', richToPlainText(_e.detail));
    add('ملاحظات', _e.notes);
    add('المصدر', _e.source);
    Clipboard.setData(ClipboardData(text: b.toString().trim()));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم نسخ المعلومة')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: gradientAppBar(context, 'عرض المعلومة', actions: [
          IconButton(
              onPressed: _copyAll,
              icon: const Icon(Icons.copy_all),
              tooltip: 'نسخ'),
          IconButton(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل'),
          IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'حذف'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // مسار التخصص.
          if (_e.mainSpecialty.isNotEmpty || _e.subSpecialty.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_e.mainSpecialty.isNotEmpty)
                  _chip(
                    _e.mainSpecialty,
                    scheme.primaryContainer,
                    scheme.onPrimaryContainer,
                    Icons.account_tree_outlined,
                    onTap: () => _openSpecialty(main: _e.mainSpecialty),
                  ),
                if (_e.subSpecialty.isNotEmpty) ...[
                  Icon(Icons.chevron_left, size: 18, color: theme.hintColor),
                  _chip(
                    _e.subSpecialty,
                    scheme.secondaryContainer,
                    scheme.onSecondaryContainer,
                    Icons.subdirectory_arrow_left,
                    onTap: () => _openSpecialty(
                        main: _e.mainSpecialty.isEmpty ? null : _e.mainSpecialty,
                        sub: _e.subSpecialty),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 14),
          // العنوان (الموضوع).
          if (_e.topic.isNotEmpty)
            SelectableText(
              _e.topic,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.event, size: 15, color: theme.hintColor),
              const SizedBox(width: 4),
              Text('تاريخ الإضافة: ${_date(_e.createdAt)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ],
          ),
          const SizedBox(height: 16),
          // المختصر — بطاقة بارزة.
          if (_e.brief.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border(
                    right: BorderSide(color: scheme.primary, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.short_text, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text('المختصر',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: scheme.primary)),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText(_e.brief,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(height: 1.6, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          _richSection('التفصيل', Icons.notes, _e.detail, theme),
          _section('ملاحظات', Icons.sticky_note_2_outlined, _e.notes, theme),
          _section('المصدر', Icons.link, _e.source, theme),
        ],
      ),
    );
  }

  void _openSpecialty({String? main, String? sub}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InfoListScreen(filterMain: main, filterSub: sub),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg, IconData icon,
          {VoidCallback? onTap}) =>
      Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(text,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
              if (onTap != null) ...[
                const SizedBox(width: 3),
                Icon(Icons.unfold_more, size: 14, color: fg),
              ],
            ]),
          ),
        ),
      );

  /// قسم «التفصيل» — يعرض النص الغني بتنسيقه.
  Widget _richSection(
      String label, IconData icon, String value, ThemeData theme) {
    if (richToPlainText(value).trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 14),
          RichTextViewer(content: value),
        ],
      ),
    );
  }

  Widget _section(String label, IconData icon, String value, ThemeData theme) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 14),
          SelectableText(value,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.7)),
        ],
      ),
    );
  }
}
