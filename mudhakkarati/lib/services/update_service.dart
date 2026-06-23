import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// معلومات نسخة متوفّرة للتحديث.
class UpdateInfo {
  final String version; // اسم النسخة (مثل 1.4.2)
  final int build; // رقم البناء البعيد
  final String url; // رابط ملف الـ APK
  const UpdateInfo(this.version, this.build, this.url);
}

/// تحديث التطبيق داخليًّا (لتطبيق مُثبَّت يدويًّا خارج المتجر):
/// - يقرأ `version.json` المنشور مع كل بناء على فرع apk-dist.
/// - يقارن رقم البناء البعيد برقم بناء التطبيق الحالي.
/// - عند توفّر أحدث: يحمّل الـ APK ويشغّل مثبّت النظام (يبقى تأكيد التثبيت على
///   المستخدم — إجباريّ لأي تطبيق خارج Google Play).
class UpdateService {
  UpdateService._();
  static final instance = UpdateService._();

  static const _versionUrl =
      'https://raw.githubusercontent.com/alaoufi/alaoufi_notes/apk-dist/version.json';
  static const _fallbackApk =
      'https://raw.githubusercontent.com/alaoufi/alaoufi_notes/apk-dist/AlaoufiNotes.apk';

  /// يعيد معلومات التحديث إن توفّرت نسخة أحدث، وإلا null (بلا أخطاء ظاهرة).
  Future<UpdateInfo?> check() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      final req = await client.getUrl(Uri.parse(_versionUrl));
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final remoteBuild = (j['build'] as num?)?.toInt() ?? 0;
      final remoteVer = (j['version'] as String?) ?? '';
      final url = (j['url'] as String?) ?? _fallbackApk;

      final info = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(info.buildNumber) ?? 0;
      if (remoteBuild > localBuild) {
        return UpdateInfo(remoteVer, remoteBuild, url);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// يحمّل الـ APK من [url] (مع تقدّم اختياريّ) ثم يفتحه بمثبّت النظام.
  /// يعيد رسالة خطأ عند الفشل، أو null عند النجاح.
  Future<String?> downloadAndInstall(String url,
      {void Function(double progress)? onProgress}) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        return 'تعذّر التحميل (HTTP ${res.statusCode})';
      }
      final total = res.contentLength;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/AlaoufiNotes_update.apk');
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.flush();
      await sink.close();

      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        return result.message;
      }
      return null;
    } catch (e) {
      return 'فشل التحديث: $e';
    }
  }
}
