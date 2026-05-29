import 'enums.dart';

/// تذكير مرتبط بملاحظة. يُجدول كإشعار محلي.
class Reminder {
  final int? id;
  final int noteId;
  final DateTime time;
  final ReminderRepeat repeat;
  final bool isActive;

  /// معرّف الإشعار في flutter_local_notifications (لإلغائه لاحقًا).
  final int notificationId;

  const Reminder({
    this.id,
    required this.noteId,
    required this.time,
    this.repeat = ReminderRepeat.once,
    this.isActive = true,
    required this.notificationId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'note_id': noteId,
      'time': time.millisecondsSinceEpoch,
      'repeat': repeat.dbValue,
      'is_active': isActive ? 1 : 0,
      'notification_id': notificationId,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      noteId: map['note_id'] as int,
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      repeat: ReminderRepeatX.fromDb(map['repeat'] as String?),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      notificationId: map['notification_id'] as int,
    );
  }

  Reminder copyWith({
    int? id,
    int? noteId,
    DateTime? time,
    ReminderRepeat? repeat,
    bool? isActive,
    int? notificationId,
  }) {
    return Reminder(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
      isActive: isActive ?? this.isActive,
      notificationId: notificationId ?? this.notificationId,
    );
  }
}
