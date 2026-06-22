import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/text/line_direction.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/note_gradient.dart';
import '../features/settings/settings_provider.dart';
import '../data/models/category.dart';
import '../data/models/enums.dart';
import '../data/models/note.dart';
import '../data/models/password_entry.dart';
import '../features/editor/rich_text_field.dart';
import '../features/home/notes_provider.dart';

/// بطاقة عرض ملاحظة في الصفحة الرئيسية.
class NoteCard extends StatelessWidget {
  final Note note;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// عند true تُعرض محتويات الملاحظة المقفلة (داخل القسم السري بعد فتح القفل).
  final bool revealLocked;

  const NoteCard({
    super.key,
    required this.note,
    required this.category,
    required this.onTap,
    required this.onLongPress,
    this.revealLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.resolveNoteColor(note.color, isDark);
    final grad = NoteGradient.parse(note.gradient);
    final onBg = grad != null
        ? grad.onColor
        : (ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return Card(
      // الشبكة تتكفّل بالتباعد؛ نُلغي هامش الثيم العام كي لا تتباعد البطاقات.
      margin: EdgeInsets.zero,
      color: grad != null ? Colors.transparent : bg,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: grad != null
            ? BoxDecoration(gradient: grad.toGradient())
            : null,
        child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_typeIcon, size: 18, color: onBg.withOpacity(0.6)),
                  const Spacer(),
                  if (note.isFavorite)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.star,
                          size: 16, color: Colors.amber.shade700),
                    ),
                  if (note.isLocked)
                    Icon(Icons.lock, size: 16, color: onBg.withOpacity(0.6)),
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin,
                          size: 16, color: onBg.withOpacity(0.7)),
                    ),
                ],
              ),
              if (note.title.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: lineDirection(note.title),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: onBg,
                  ),
                ),
              ],
              if (note.isLocked && !revealLocked)
                _lockedBody(context, onBg)
              else if (context.watch<SettingsProvider>().privacyMode)
                _hiddenBody(context, onBg)
              else ...[
                _body(context, onBg),
                _tagChips(context, onBg),
              ],
              _footer(onBg),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// تذييل منظّم: شارة التصنيف (نقطة ملوّنة + اسم) والتاريخ.
  Widget _footer(Color onBg) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: category == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Color(category!.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          category!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: onBg.withOpacity(0.65)),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            _shortDate(note.updatedAt),
            style: TextStyle(fontSize: 10.5, color: onBg.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${two(d.hour)}:${two(d.minute)}';
    }
    if (d.year == now.year) return '${two(d.day)}/${two(d.month)}';
    return '${d.year}/${two(d.month)}/${two(d.day)}';
  }

  IconData get _typeIcon => switch (note.type) {
        NoteType.text => Icons.notes,
        NoteType.checklist => Icons.checklist,
        NoteType.image => Icons.image,
        NoteType.audio => Icons.mic,
        NoteType.pdf => Icons.picture_as_pdf,
        NoteType.drawing => Icons.brush,
        NoteType.password => Icons.vpn_key,
      };

  /// معاينة مخفية في «وضع الخصوصية» (يظهر العنوان فقط).
  Widget _hiddenBody(BuildContext context, Color onBg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined,
              size: 16, color: onBg.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text('المحتوى مخفي',
              style: TextStyle(color: onBg.withOpacity(0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _lockedBody(BuildContext context, Color onBg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: onBg.withOpacity(0.6)),
          const SizedBox(width: 8),
          Text('ملاحظة مقفلة', style: TextStyle(color: onBg.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, Color onBg) {
    switch (note.type) {
      case NoteType.image:
        if (note.imagePath != null && File(note.imagePath!).existsSync()) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(note.imagePath!),
                  height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
          );
        }
        return _text(context, onBg);
      case NoteType.drawing:
        if (note.drawingPath != null && File(note.drawingPath!).existsSync()) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(note.drawingPath!),
                  height: 120, width: double.infinity, fit: BoxFit.contain),
            ),
          );
        }
        return _text(context, onBg);
      case NoteType.audio:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Icon(Icons.play_circle_fill, color: onBg.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text('ملاحظة صوتية', style: TextStyle(color: onBg.withOpacity(0.8))),
          ]),
        );
      case NoteType.pdf:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Icon(Icons.picture_as_pdf, color: onBg.withOpacity(0.8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('ملف PDF مرفق',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onBg.withOpacity(0.8))),
            ),
          ]),
        );
      case NoteType.checklist:
        final noteFont = context.watch<SettingsProvider>().noteFontFamily;
        final allLines = note.content
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final tasks =
            allLines.where((l) => RegExp(r'^\[[ x]\]').hasMatch(l)).toList();
        final total = tasks.length;
        final doneCount = tasks.where((l) => l.startsWith('[x]')).length;
        final lines = allLines.take(4).toList();
        if (lines.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (total > 0) _checklistBar(context, onBg, doneCount, total),
              ...lines.map((l) {
              // سطر مهمة يبدأ بـ [x]/[ ]، وإلا فهو نصّ عادي بلا مربع.
              final isTask = RegExp(r'^\[[ x]\]\s?').hasMatch(l);
              final done = l.startsWith('[x]');
              final text = isTask ? l.replaceFirst(RegExp(r'^\[.\]\s?'), '') : l;
              return Directionality(
                textDirection: lineDirection(text),
                child: Row(children: [
                  if (isTask) ...[
                    Icon(
                        done
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: onBg.withOpacity(0.7)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onBg.withOpacity(0.85),
                          fontFamily: noteFont,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                        )),
                  ),
                ]),
              );
            }),
            ],
          ),
        );
      case NoteType.password:
        final entry = PasswordEntry.fromStoredJson(note.content);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: onBg, fontWeight: FontWeight.w600)),
              if (entry.username.trim().isNotEmpty)
                Text(entry.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: onBg.withOpacity(0.8))),
              Text('••••••••', style: TextStyle(color: onBg.withOpacity(0.6))),
            ],
          ),
        );
      case NoteType.text:
        return _text(context, onBg);
    }
  }

  /// شرائح الوسوم الملوّنة على البطاقة (حتى 3 + «N+») — تُظهر التنظيم بنظرة.
  Widget _tagChips(BuildContext context, Color onBg) {
    if (note.tags.isEmpty) return const SizedBox.shrink();
    final colors = context.watch<NotesProvider>().tagColors;
    Color colorOf(String t) {
      final c = colors[t];
      if (c != null) return Color(c);
      final hue = (t.hashCode % 360).abs().toDouble();
      return HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();
    }

    final shown = note.tags.take(3).toList();
    final extra = note.tags.length - shown.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final t in shown)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorOf(t).withOpacity(0.16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorOf(t).withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: colorOf(t), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(t,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: onBg.withOpacity(0.85))),
                ],
              ),
            ),
          if (extra > 0)
            Text('+$extra',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: onBg.withOpacity(0.6))),
        ],
      ),
    );
  }

  /// شريط تقدّم مدمج لقائمة المهام على البطاقة (المنجَز/الإجمالي).
  Widget _checklistBar(BuildContext context, Color onBg, int done, int total) {
    final ratio = total == 0 ? 0.0 : done / total;
    final complete = done == total;
    final color = complete ? Colors.green : onBg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(complete ? Icons.check_circle : Icons.checklist,
                  size: 13, color: color.withOpacity(0.8)),
              const SizedBox(width: 4),
              Text('$done/$total',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.8))),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: onBg.withOpacity(0.15),
              color: complete ? Colors.green : onBg.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(BuildContext context, Color onBg) {
    final plain = richToPlainText(note.content);
    if (plain.trim().isEmpty) return const SizedBox.shrink();
    final noteFont = context.watch<SettingsProvider>().noteFontFamily;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: AutoDirText(
        plain,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: onBg.withOpacity(0.8),
            height: 1.3,
            fontSize: 13,
            fontFamily: noteFont),
      ),
    );
  }
}
