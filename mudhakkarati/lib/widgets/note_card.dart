import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/category.dart';
import '../data/models/enums.dart';
import '../data/models/note.dart';
import '../data/models/password_entry.dart';
import '../features/editor/rich_text_field.dart';

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
    final onBg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Card(
      color: bg,
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: onBg,
                  ),
                ),
              ],
              if (note.isLocked && !revealLocked)
                _lockedBody(context, onBg)
              else
                _body(context, onBg),
            ],
          ),
        ),
      ),
    );
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
        return _text(onBg);
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
        return _text(onBg);
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
        final lines = note.content
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .take(4)
            .toList();
        if (lines.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((l) {
              final done = l.startsWith('[x]');
              final text = l.replaceFirst(RegExp(r'^\[.\]\s?'), '');
              return Row(children: [
                Icon(done ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 16, color: onBg.withOpacity(0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onBg.withOpacity(0.85),
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                      )),
                ),
              ]);
            }).toList(),
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
        return _text(onBg);
    }
  }

  Widget _text(Color onBg) {
    final plain = richToPlainText(note.content);
    if (plain.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        plain,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: onBg.withOpacity(0.8), height: 1.3, fontSize: 13),
      ),
    );
  }
}
