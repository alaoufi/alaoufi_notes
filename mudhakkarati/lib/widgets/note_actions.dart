import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/note.dart';
import '../features/home/notes_provider.dart';
import '../features/reminders/reminder_dialog.dart';
import 'color_picker_sheet.dart';

/// شيت إجراءات الملاحظة (عند الضغط المطوّل أو من المحرر).
Future<void> showNoteActions(BuildContext context, Note note) async {
  final s = S.of(context);
  final provider = context.read<NotesProvider>();

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) {
      Widget tile(IconData icon, String label, VoidCallback onTap,
          {Color? color}) {
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label, style: TextStyle(color: color)),
          onTap: onTap,
        );
      }

      return SafeArea(
        child: Wrap(
          children: [
            tile(
              note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              note.isPinned ? s.t('unpin') : s.t('pin'),
              () async {
                Navigator.pop(context);
                await provider.togglePin(note);
              },
            ),
            tile(Icons.palette_outlined, s.t('color'), () async {
              Navigator.pop(context);
              final res = await showColorPicker(context, note.color);
              if (res != null) await provider.setColor(note, res.value);
            }),
            tile(Icons.alarm, s.t('reminder'), () async {
              Navigator.pop(context);
              await showReminderDialog(context, note);
            }),
            tile(
              note.isLocked ? Icons.lock_open : Icons.lock_outline,
              note.isLocked ? s.t('unlock') : s.t('lock'),
              () async {
                Navigator.pop(context);
                await provider.setLocked(note, !note.isLocked);
              },
            ),
            tile(Icons.copy_all, s.t('duplicate'), () async {
              Navigator.pop(context);
              await provider.duplicate(note);
            }),
            tile(Icons.content_copy, s.t('copy'), () async {
              Navigator.pop(context);
              await Clipboard.setData(
                  ClipboardData(text: _asText(note)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.t('copied'))));
              }
            }),
            tile(Icons.share, s.t('share'), () async {
              Navigator.pop(context);
              await Share.share(_asText(note));
            }),
            tile(
              note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              note.isArchived ? s.t('unarchive') : s.t('archive'),
              () async {
                Navigator.pop(context);
                await provider.setArchived(note, !note.isArchived);
              },
            ),
            tile(Icons.delete_outline, s.t('delete'), () async {
              Navigator.pop(context);
              await provider.moveToTrash(note);
            }, color: Theme.of(context).colorScheme.error),
          ],
        ),
      );
    },
  );
}

String _asText(Note note) {
  final buffer = StringBuffer();
  if (note.title.trim().isNotEmpty) buffer.writeln(note.title);
  if (note.content.trim().isNotEmpty) buffer.writeln(note.content);
  return buffer.toString().trim();
}
