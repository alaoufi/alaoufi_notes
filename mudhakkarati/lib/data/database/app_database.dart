import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'db_key.dart';

/// مدير قاعدة بيانات SQLite المحلية.
///
/// كل البيانات تُخزَّن داخل الجهاز فقط — لا اتصال بأي خادم، والملف نفسه
/// مشفّر بالكامل عبر SQLCipher (AES-256) بمفتاح محفوظ في التخزين الآمن.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'mudhakkarati.db';
  static const _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  /// مسار ملف قاعدة البيانات (يُستخدم في النسخ الاحتياطي).
  Future<String> get path async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbName);
  }

  Future<Database> _open() async {
    final dbPath = await path;
    final key = await DbKeyManager.instance.getOrCreateKey();

    // ترحيل آمن للقاعدة غير المشفّرة (نسخة قديمة) إلى مشفّرة — لمرة واحدة.
    await _migrateToEncryptedIfNeeded(dbPath, key);

    return openDatabase(
      dbPath,
      password: key,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// يحوّل قاعدة بيانات نصّية (غير مشفّرة) إلى مشفّرة بأمان دون فقدان البيانات.
  ///
  /// لا يحذف الأصل إلا بعد التحقق من فتح النسخة المشفّرة وتطابق عدد الصفوف.
  Future<void> _migrateToEncryptedIfNeeded(String dbPath, String key) async {
    if (await DbKeyManager.instance.isMigrated()) return;

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      // تثبيت جديد: ستُنشأ القاعدة مشفّرة مباشرة.
      await DbKeyManager.instance.markMigrated();
      return;
    }

    // هل الملف مشفّر بالفعل؟ نختبر فتحه بالمفتاح.
    if (await _opensWithKey(dbPath, key)) {
      await DbKeyManager.instance.markMigrated();
      return;
    }

    // الملف نصّي قديم — نحوّله.
    final encPath = '$dbPath.enc';
    final encFile = File(encPath);
    if (await encFile.exists()) await encFile.delete();

    Database? plain;
    try {
      plain = await openDatabase(dbPath); // بلا مفتاح = فتح نصّي.
      final ver = Sqflite.firstIntValue(
              await plain.rawQuery('PRAGMA user_version')) ??
          0;
      final srcNotes = Sqflite.firstIntValue(
              await plain.rawQuery('SELECT COUNT(*) FROM notes')) ??
          0;

      await plain.rawQuery(
          "ATTACH DATABASE ? AS enc KEY ?", [encPath, key]);
      await plain.rawQuery("SELECT sqlcipher_export('enc')");
      await plain.rawQuery("PRAGMA enc.user_version = $ver");
      await plain.rawQuery("DETACH DATABASE enc");
      await plain.close();
      plain = null;

      // تحقّق: افتح المشفّرة وقارن عدد الملاحظات.
      final enc = await openDatabase(encPath, password: key);
      final dstNotes = Sqflite.firstIntValue(
              await enc.rawQuery('SELECT COUNT(*) FROM notes')) ??
          -1;
      await enc.close();

      if (dstNotes != srcNotes) {
        // فشل التحقق — أبقِ الأصل ولا تبدّل شيئًا.
        if (await encFile.exists()) await encFile.delete();
        return;
      }

      // نجح: احتفظ بنسخة أمان مؤقتة ثم ضع المشفّرة مكان الأصل.
      final bak = File('$dbPath.plain.bak');
      if (await bak.exists()) await bak.delete();
      await dbFile.rename(bak.path);
      await encFile.rename(dbPath);
      await DbKeyManager.instance.markMigrated();
      // حذف نسخة الأمان النصّية (لتحقيق التشفير فعليًا).
      if (await bak.exists()) await bak.delete();
    } catch (_) {
      // أي خطأ: لا نلمس الأصل؛ ننظّف المؤقت ونؤجّل (سيعمل التطبيق نصّيًا
      // في المحاولة القادمة بعد الإصلاح، دون فقدان بيانات).
      try {
        await plain?.close();
      } catch (_) {}
      if (await encFile.exists()) await encFile.delete();
      rethrow;
    }
  }

  /// يحاول فتح القاعدة بالمفتاح؛ يعيد true إن نجح (أي أنها مشفّرة بالفعل).
  Future<bool> _opensWithKey(String dbPath, String key) async {
    try {
      final db = await openDatabase(dbPath, password: key, readOnly: true);
      await db.rawQuery('SELECT count(*) FROM sqlite_master');
      await db.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// إعادة فتح قاعدة البيانات (بعد استعادة نسخة احتياطية).
  Future<void> reopen() async {
    await _db?.close();
    _db = null;
    _db = await _open();
  }


  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        icon_code INTEGER NOT NULL,
        position INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'text',
        color INTEGER,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        category_id INTEGER,
        image_path TEXT,
        audio_path TEXT,
        pdf_path TEXT,
        drawing_path TEXT,
        bg_style INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE checklist_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        is_done INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE note_tags (
        note_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (note_id, tag_id),
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL,
        time INTEGER NOT NULL,
        repeat TEXT NOT NULL DEFAULT 'once',
        is_active INTEGER NOT NULL DEFAULT 1,
        notification_id INTEGER NOT NULL,
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_notes_category ON notes (category_id)');
    await db.execute('CREATE INDEX idx_notes_flags ON notes (is_deleted, is_archived)');
    await db.execute('CREATE INDEX idx_checklist_note ON checklist_items (note_id)');
    await db.execute('CREATE INDEX idx_reminders_note ON reminders (note_id)');

    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE notes ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE notes ADD COLUMN bg_style INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// التصنيفات الافتراضية المطلوبة: شخصي، عمل، مهم، مواعيد، أفكار.
  Future<void> _seedDefaultCategories(Database db) async {
    // icon_code يخزّن *فهرس* الأيقونة في kCategoryIcons (وليس codePoint).
    final defaults = <Map<String, dynamic>>[
      {'name': 'شخصي', 'color': 0xFF42A5F5, 'icon_code': 0, 'position': 0},
      {'name': 'عمل', 'color': 0xFF7E57C2, 'icon_code': 1, 'position': 1},
      {'name': 'مهم', 'color': 0xFFEF5350, 'icon_code': 2, 'position': 2},
      {'name': 'مواعيد', 'color': 0xFF26A69A, 'icon_code': 3, 'position': 3},
      {'name': 'أفكار', 'color': 0xFFFFA726, 'icon_code': 4, 'position': 4},
    ];
    for (final c in defaults) {
      await db.insert('categories', c);
    }
  }
}
