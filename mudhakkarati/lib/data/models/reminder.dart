import 'enums.dart';

/// تذكير — قد يكون مرتبطًا بملاحظة ([noteId]) أو مستقلًّا بعنوان حرّ ([title]).
class Reminder {
  final int? id;
  final int? noteId; // null ⇒ تنبيه مستقلّ غير مرتبط بملاحظة
  final String? title; // عنوان التنبيه المستقلّ
  final DateTime time;
  final ReminderRepeat repeat;
  final bool isActive;

  /// مستوى الأهمية (يحدّد سلوك التنبيه: صوت/اهتزاز/شاشة كاملة/إصرار).
  final ReminderImportance importance;

  /// معرّف الإشعار في flutter_local_notifications (لإلغائه لاحقًا).
  final int notificationId;

  const Reminder({
    this.id,
    this.noteId,
    this.title,
    required this.time,
    this.repeat = ReminderRepeat.once,
    this.isActive = true,
    this.importance = ReminderImportance.high,
    required this.notificationId,
  });

  /// تنبيه مستقلّ (غير مرتبط بملاحظة).
  bool get isStandalone => noteId == null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'note_id': noteId,
      'title': title,
      'time': time.millisecondsSinceEpoch,
      'repeat': repeat.dbValue,
      'is_active': isActive ? 1 : 0,
      'notification_id': notificationId,
      'importance': importance.dbValue,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      noteId: map['note_id'] as int?,
      title: map['title'] as String?,
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      repeat: ReminderRepeatX.fromDb(map['repeat'] as String?),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      notificationId: map['notification_id'] as int,
      importance: ReminderImportanceX.fromDb(map['importance'] as String?),
    );
  }

  Reminder copyWith({
    int? id,
    int? noteId,
    String? title,
    DateTime? time,
    ReminderRepeat? repeat,
    bool? isActive,
    ReminderImportance? importance,
    int? notificationId,
  }) {
    return Reminder(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      time: time ?? this.time,
      repeat: repeat ?? this.repeat,
      isActive: isActive ?? this.isActive,
      importance: importance ?? this.importance,
      notificationId: notificationId ?? this.notificationId,
    );
  }
}
