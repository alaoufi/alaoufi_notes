import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// مدير قاعدة بيانات SQLite المحلية.
///
/// كل البيانات تُخزَّن داخل الجهاز فقط — لا اتصال بأي خادم.
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
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
