/// أنواع الملاحظات المدعومة في التطبيق.
enum NoteType {
  text, // ملاحظة نصية
  checklist, // قائمة مهام
  image, // ملاحظة بصورة
  audio, // ملاحظة صوتية
  pdf, // ملاحظة مع ملف PDF
  drawing, // رسم / كتابة يدوية
}

extension NoteTypeX on NoteType {
  String get dbValue => name;

  static NoteType fromDb(String? value) {
    return NoteType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NoteType.text,
    );
  }
}

/// تكرار التذكير.
enum ReminderRepeat {
  once, // مرة واحدة
  daily, // يومي
  weekly, // أسبوعي
  monthly, // شهري
  yearly, // سنوي
}

extension ReminderRepeatX on ReminderRepeat {
  String get dbValue => name;

  static ReminderRepeat fromDb(String? value) {
    return ReminderRepeat.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReminderRepeat.once,
    );
  }
}

/// طريقة عرض الملاحظات في الصفحة الرئيسية.
enum NoteLayout { grid, list }
