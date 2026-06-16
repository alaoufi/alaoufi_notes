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
    add('الملخص', _e.brief);
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
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // رأس عصري كبير بتدرّج لوني — يعرض الموضوع كاملًا.
          SliverAppBar.large(
            pinned: true,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            actions: [
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
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 14),
              title: Text(
                _e.topic.isNotEmpty ? _e.topic : 'عرض المعلومة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      scheme.primary,
                      Color.alphaBlend(
                          Colors.black.withOpacity(0.16), scheme.primary),
                      scheme.tertiary,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
            sliver: SliverList.list(children: [
              // مسار التخصص (قابل للنقر).
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
                            main: _e.mainSpecialty.isEmpty
                                ? null
                                : _e.mainSpecialty,
                            sub: _e.subSpecialty),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.event, size: 15, color: theme.hintColor),
                const SizedBox(width: 4),
                Text('تاريخ الإضافة: ${_date(_e.createdAt)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
              ]),
              // الأقسام كبطاقات ثلاثية الأبعاد (تستوعب التنسيق).
              _card3d('الملخص', Icons.short_text, dark, scheme,
                  highlight: true,
                  child: SelectableText(_e.brief,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6, fontWeight: FontWeight.w600))),
              _card3d('التفصيل', Icons.notes, dark, scheme,
                  rich: _e.detail),
              _card3d('ملاحظات', Icons.sticky_note_2_outlined, dark, scheme,
                  child: SelectableText(_e.notes,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.7))),
              _card3d('المصدر', Icons.link, dark, scheme,
                  child: SelectableText(_e.source,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))),
            ]),
          ),
        ],
      ),
    );
  }

  /// بطاقة قسم ثلاثية الأبعاد (تدرّج + حدّ + ظلّ + شارة أيقونة). تُخفى إن فرغت.
  /// [rich] لعرض نصّ غنيّ بتنسيقه؛ وإلا [child] لنصّ عادي.
  Widget _card3d(String label, IconData icon, bool dark, ColorScheme scheme,
      {Widget? child, String? rich, bool highlight = false}) {
    if (rich != null) {
      if (richToPlainText(rich).trim().isEmpty) return const SizedBox.shrink();
    } else if (child is SelectableText) {
      if ((child.data ?? '').trim().isEmpty) return const SizedBox.shrink();
    }
    final surface = dark ? const Color(0xFF1E2230) : Colors.white;
    final accent = scheme.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surface,
            Color.alphaBlend(
                accent.withOpacity(highlight ? 0.10 : 0.05), surface),
          ],
        ),
        border: Border.all(
            color: accent.withOpacity(highlight ? 0.40 : 0.16),
            width: highlight ? 1.4 : 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.4 : 0.07),
              offset: const Offset(0, 8),
              blurRadius: 18,
              spreadRadius: -6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            gradientBadge(icon, accent, size: 34, radius: 10, iconSize: 18),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: scheme.onSurface)),
          ]),
          const SizedBox(height: 12),
          if (rich != null) RichTextViewer(content: rich) else child!,
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

}
