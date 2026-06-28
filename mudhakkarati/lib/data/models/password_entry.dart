import 'dart:convert';

import '../../services/vault_service.dart';

/// بيانات ملاحظة كلمات المرور (حقول منظمة).
///
/// تُخزَّن داخل حقل `content` للملاحظة كـ JSON. قاعدة البيانات نفسها مشفّرة
/// بالكامل (SQLCipher)، لذا تُحفظ الحقول كنصّ عادي ليعمل البحث. الملاحظات
/// القديمة التي شُفّرت كلمة مرورها سابقًا (`password_enc`) تُفكّ عند القراءة
/// للتوافق الرجعيّ.
class PasswordEntry {
  final String name; // الاسم
  final String link; // الرابط
  final String username; // اسم المستخدم
  final String password; // كلمة المرور (نصّ عادي — القاعدة مشفّرة)
  final String notes; // ملاحظات

  const PasswordEntry({
    this.name = '',
    this.link = '',
    this.username = '',
    this.password = '',
    this.notes = '',
  });

  PasswordEntry copyWith({
    String? name,
    String? link,
    String? username,
    String? password,
    String? notes,
  }) {
    return PasswordEntry(
      name: name ?? this.name,
      link: link ?? this.link,
      username: username ?? this.username,
      password: password ?? this.password,
      notes: notes ?? this.notes,
    );
  }

  /// يحوّل إلى JSON قابل للتخزين (كلّ الحقول نصّ عادي — القاعدة مشفّرة).
  String toStoredJson() {
    return jsonEncode({
      'name': name,
      'link': link,
      'username': username,
      'password': password,
      'notes': notes,
    });
  }

  /// يقرأ من JSON المخزَّن. يدعم المفاتيح الجديدة (name/link/password) والقديمة
  /// (site/app/password_enc) معًا، ويفكّ تشفير كلمات المرور القديمة.
  factory PasswordEntry.fromStoredJson(String raw) {
    if (raw.trim().isEmpty) return const PasswordEntry();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      // كلمة المرور: الجديدة نصّ عادي، والقديمة مشفّرة (password_enc).
      var pw = (map['password'] as String?) ?? '';
      if (pw.isEmpty) {
        final enc = (map['password_enc'] as String?) ?? '';
        if (enc.isNotEmpty) {
          try {
            pw = VaultService.instance.decrypt(enc);
          } catch (_) {
            pw = '';
          }
        }
      }
      return PasswordEntry(
        name: (map['name'] as String?) ?? (map['site'] as String?) ?? '',
        link: (map['link'] as String?) ?? (map['app'] as String?) ?? '',
        username: (map['username'] as String?) ?? '',
        password: pw,
        notes: (map['notes'] as String?) ?? '',
      );
    } catch (_) {
      return const PasswordEntry();
    }
  }

  /// نص مختصر يُعرض في البطاقة (بدون كلمة المرور).
  String get displayTitle {
    if (name.trim().isNotEmpty) return name;
    if (link.trim().isNotEmpty) return link;
    if (username.trim().isNotEmpty) return username;
    return 'كلمة مرور';
  }
}
