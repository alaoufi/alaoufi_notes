import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// يثبت أنّ مذكراتي يقبل أكواد **المفتاح العالميّ (UNIV1)** — باستخدام متّجهات
/// الاختبار الرسميّة من دليل المطوّر. يطابق منطق LicenseService.tryActivate:
/// فكّ Base32 → [مدّة(2) + توقيع(64)] → تحقّق Ed25519 من "UNIV1|deviceId|duration".
void main() {
  const pubB64 = '0JXPjbbPjczfYbYxl+jy1vOVcsEJT+CPbUIQgXNCStU=';
  const b32 = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  List<int> base32Decode(String s) {
    var bits = 0, value = 0;
    final out = <int>[];
    for (final ch in s.split('')) {
      final idx = b32.indexOf(ch);
      if (idx < 0) continue;
      value = (value << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        out.add((value >> (bits - 8)) & 0xff);
        bits -= 8;
      }
      value &= (1 << bits) - 1;
    }
    return out;
  }

  Future<bool> verify(String code, String deviceId) async {
    final norm = code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final bytes = base32Decode(norm);
    if (bytes.length != 66) return false;
    final duration = (bytes[0] << 8) | bytes[1];
    final sig = bytes.sublist(2);
    final msg = utf8.encode('UNIV1|$deviceId|$duration');
    final pub =
        SimplePublicKey(base64Decode(pubB64), type: KeyPairType.ed25519);
    return Ed25519().verify(msg, signature: Signature(sig, publicKey: pub));
  }

  test('كود دائم (المدّة 0) يُقبل لجهاز الاختبار', () async {
    const code =
        'AAANSJ2UELQ398JB5X4FPSV9DWUW3XSRP367RBVF9ASD7URBN55UTUBRMHWNYEQTL6HQLVS43XA5B3K7QK2ZU7FF4GX8PJB93BE4CKB2AJ';
    expect(await verify(code, 'TESTDEVICE234567'), isTrue);
  });

  test('كود ٣٠ يومًا يُقبل لجهاز الاختبار', () async {
    const code =
        'AARLNZUCVGUA827D3FUBNPHB9ESX6KZX4EWUEM7NX7LU2CJ5XX4JPZSBUPAWUDNKH2TAP2P7992LQ99UNV9HP55BME68X8EM8FBU69UBAJ';
    expect(await verify(code, 'TESTDEVICE234567'), isTrue);
  });

  test('كود صحيح يُرفض لجهاز مختلف', () async {
    const code =
        'AAANSJ2UELQ398JB5X4FPSV9DWUW3XSRP367RBVF9ASD7URBN55UTUBRMHWNYEQTL6HQLVS43XA5B3K7QK2ZU7FF4GX8PJB93BE4CKB2AJ';
    expect(await verify(code, 'OTHERDEVICE00000'), isFalse);
  });
}
