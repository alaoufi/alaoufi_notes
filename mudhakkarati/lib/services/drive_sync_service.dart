import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// مزامنة النسخة الاحتياطية المشفّرة مع Google Drive (مجلّد appDataFolder الخاص
/// بالتطبيق — لا يراه المستخدم في Drive ولا تطبيقات أخرى).
///
/// يتطلب تهيئة google_sign_in بـ OAuth Client ID (يُعدّ مرة واحدة).
class DriveSyncService {
  DriveSyncService._();
  static final DriveSyncService instance = DriveSyncService._();

  static const _backupName = 'alaoufi_notes_backup.mdkbak';
  static const _scopes = [drive.DriveApi.driveAppdataScope];

  GoogleSignIn get _signIn => GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _signIn.initialize();
    _initialized = true;
  }

  /// هل المستخدم مسجّل دخوله حاليًا؟
  Future<bool> isSignedIn() async {
    await _ensureInit();
    final user = await _signIn.attemptLightweightAuthentication();
    return user != null;
  }

  /// البريد المسجّل (إن وُجد).
  Future<String?> currentEmail() async {
    await _ensureInit();
    final user = await _signIn.attemptLightweightAuthentication();
    return user?.email;
  }

  Future<void> signOut() async {
    await _ensureInit();
    await _signIn.signOut();
  }

  /// تسجيل الدخول التفاعلي (يفتح اختيار حساب Google).
  Future<bool> signIn() async {
    await _ensureInit();
    try {
      final user = await _signIn.authenticate(scopeHint: _scopes);
      return user.email.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<drive.DriveApi?> _api() async {
    await _ensureInit();
    final user = await _signIn.attemptLightweightAuthentication();
    if (user == null) return null;
    final headers = await user.authorizationClient
        .authorizationHeaders(_scopes, promptIfNecessary: true);
    if (headers == null) return null;
    return drive.DriveApi(_AuthClient(headers));
  }

  /// رفع ملف نسخة احتياطية مشفّرة إلى Drive (يستبدل القديم).
  Future<bool> upload(Uint8List encryptedBytes) async {
    final api = await _api();
    if (api == null) return false;
    final existingId = await _findBackupId(api);

    final media = drive.Media(
      Stream.value(encryptedBytes),
      encryptedBytes.length,
    );

    if (existingId != null) {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    } else {
      final meta = drive.File()
        ..name = _backupName
        ..parents = ['appDataFolder'];
      await api.files.create(meta, uploadMedia: media);
    }
    return true;
  }

  /// تنزيل آخر نسخة احتياطية من Drive (أو null إن لم توجد).
  Future<Uint8List?> download() async {
    final api = await _api();
    if (api == null) return null;
    final id = await _findBackupId(api);
    if (id == null) return null;

    final media = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final out = <int>[];
    await for (final chunk in media.stream) {
      out.addAll(chunk);
    }
    return Uint8List.fromList(out);
  }

  /// تاريخ آخر نسخة على Drive (للعرض).
  Future<DateTime?> lastBackupTime() async {
    final api = await _api();
    if (api == null) return null;
    final id = await _findBackupId(api);
    if (id == null) return null;
    final f = await api.files.get(id, $fields: 'modifiedTime') as drive.File;
    return f.modifiedTime;
  }

  Future<String?> _findBackupId(drive.DriveApi api) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupName'",
      $fields: 'files(id, name)',
    );
    final files = res.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }
}

/// عميل HTTP يضيف ترويسات المصادقة لكل طلب.
class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
