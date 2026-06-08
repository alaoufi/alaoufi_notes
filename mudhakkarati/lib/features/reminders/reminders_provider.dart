import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import '../../data/models/reminder.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../services/notification_service.dart';

/// عنصر عرض يجمع التذكير مع ملاحظته.
class ReminderView {
  final Reminder reminder;
  final Note? note;
  const ReminderView(this.reminder, this.note);
}

class RemindersProvider extends ChangeNotifier {
  final ReminderRepository _repo;
  final NoteRepository _notes;

  RemindersProvider(this._repo, this._notes);

  List<ReminderView> _items = [];
  List<ReminderView> get items => _items;

  Future<void> refresh() async {
    final reminders = await _repo.getAll();
    final views = <ReminderView>[];
    for (final r in reminders) {
      final note = await _notes.getNote(r.noteId);
      // نتجاهل تذكيرات الملاحظات المحذوفة نهائيًا.
      if (note != null && !note.isDeleted) {
        views.add(ReminderView(r, note));
      }
    }
    _items = views;
    notifyListeners();
  }

  Future<Reminder?> getForNote(int noteId) => _repo.getForNote(noteId);

  /// تعيين (أو تحديث) تذكير لملاحظة وجدولته كإشعار محلي.
  Future<void> setReminder(
    Note note,
    DateTime time,
    ReminderRepeat repeat,
  ) async {
    // إلغاء القديم إن وُجد.
    final existing = await _repo.getForNote(note.id!);
    if (existing != null) {
      await NotificationService.instance.cancel(existing.notificationId);
      await _repo.delete(existing.id!);
    }

    final notifId = _generateId();
    final reminder = Reminder(
      noteId: note.id!,
      time: time,
      repeat: repeat,
      notificationId: notifId,
    );
    final id = await _repo.insert(reminder);
    await NotificationService.instance.schedule(
      reminder.copyWith(id: id),
      note.title.isNotEmpty ? note.title : 'تذكير',
      note.content,
    );
    await refresh();
  }

  Future<void> removeReminder(Reminder reminder) async {
    await NotificationService.instance.cancel(reminder.notificationId);
    await _repo.delete(reminder.id!);
    await refresh();
  }

  Future<void> removeForNote(int noteId) async {
    final r = await _repo.getForNote(noteId);
    if (r != null) {
      await NotificationService.instance.cancel(r.notificationId);
      await _repo.deleteForNote(noteId);
      await refresh();
    }
  }

  int _generateId() => Random().nextInt(1 << 30) + 1;
}
