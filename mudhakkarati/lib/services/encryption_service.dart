import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// تشفير/فك تشفير بيانات النسخ الاحتياطية باستخدام AES-256.
///
/// يُشتق المفتاح من كلمة مرور المستخدم عبر PBKDF2 (تكرار SHA-256).
/// كل شيء يتم داخل الجهاز — لا يُرسل أي شيء للخارج.
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  static const _magic = 'MDK1'; // توقيع الملف للتحقق من صحته
  static const _iterations = 12000;

  /// اشتقاق مفتاح 32 بايت من كلمة المرور والـ salt.
  Uint8List _deriveKey(String password, Uint8List salt) {
    var bytes = utf8.encode(password) + salt;
    var digest = sha256.convert(bytes).bytes;
    for (var i = 1; i < _iterations; i++) {
      digest = sha256.convert(digest + salt).bytes;
    }
    return Uint8List.fromList(digest);
  }

  Uint8List _randomBytes(int n) {
    final key = enc.Key.fromSecureRandom(n);
    return key.bytes;
  }

  /// يشفّر [data] ويعيد حزمة بايتات قابلة للحفظ في ملف.
  /// التنسيق: MAGIC(4) | salt(16) | iv(16) | ciphertext
  Uint8List encryptBytes(Uint8List data, String password) {
    final salt = _randomBytes(16);
    final iv = enc.IV.fromSecureRandom(16);
    final key = enc.Key(_deriveKey(password, salt));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);

    final builder = BytesBuilder();
    builder.add(utf8.encode(_magic));
    builder.add(salt);
    builder.add(iv.bytes);
    builder.add(encrypted.bytes);
    return builder.toBytes();
  }

  /// يفكّ تشفير حزمة أنشأها [encryptBytes]. يرمي استثناءً عند كلمة مرور خاطئة.
  Uint8List decryptBytes(Uint8List packed, String password) {
    final magic = utf8.decode(packed.sublist(0, 4));
    if (magic != _magic) {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح');
    }
    final salt = packed.sublist(4, 20);
    final iv = enc.IV(packed.sublist(20, 36));
    final cipher = packed.sublist(36);

    final key = enc.Key(_deriveKey(password, Uint8List.fromList(salt)));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipher), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  /// تجزئة كلمة المرور/الرقم السري لتخزينه بأمان (للتحقق فقط).
  String hashSecret(String secret, String salt) {
    return sha256.convert(utf8.encode('$salt::$secret')).toString();
  }

  // ---------------------------------------------------------------------------
  // تشفير حقول قصيرة بمفتاح خام ثابت (لحقول كلمات المرور) — سريع.
  // التنسيق المُعاد (Base64): iv(16) | ciphertext
  // ---------------------------------------------------------------------------

  String encryptWithKey(String plain, Uint8List key) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    final packed = Uint8List.fromList(iv.bytes + encrypted.bytes);
    return base64Encode(packed);
  }

  String decryptWithKey(String packedBase64, Uint8List key) {
    if (packedBase64.isEmpty) return '';
    try {
      final packed = base64Decode(packedBase64);
      final iv = enc.IV(Uint8List.fromList(packed.sublist(0, 16)));
      final cipher = Uint8List.fromList(packed.sublist(16));
      final encrypter =
          enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted(cipher), iv: iv);
    } catch (_) {
      return '';
    }
  }
}
