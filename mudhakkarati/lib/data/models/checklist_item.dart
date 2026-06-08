/// عنصر في قائمة مهام (Checklist) مرتبط بملاحظة.
class ChecklistItem {
  final int? id;
  final int noteId;
  final String text;
  final bool isDone;
  final int position;

  const ChecklistItem({
    this.id,
    required this.noteId,
    required this.text,
    this.isDone = false,
    this.position = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'note_id': noteId,
      'text': text,
      'is_done': isDone ? 1 : 0,
      'position': position,
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as int?,
      noteId: map['note_id'] as int,
      text: (map['text'] as String?) ?? '',
      isDone: (map['is_done'] as int? ?? 0) == 1,
      position: map['position'] as int? ?? 0,
    );
  }

  ChecklistItem copyWith({
    int? id,
    int? noteId,
    String? text,
    bool? isDone,
    int? position,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      position: position ?? this.position,
    );
  }
}
