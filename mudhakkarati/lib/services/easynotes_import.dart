import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/models/category.dart';
import '../data/models/enums.dart';
import '../data/models/note.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/note_repository.dart';
import 'file_service.dart';

class EasyNotesImportResult {
  final bool success;
  final int imported;
  final int skipped;
  final int newCategories;
  final String message;

  EasyNotesImportResult({
    required this.success,
    this.imported = 0,
    this.skipped = 0,
    this.newCategories = 0,
    required this.message,
  });
}

/// يستورد ملاحظات تطبيق Easy Notes من ملف نسخته الاحتياطية (.backup).
///
/// صيغة الملف: أرشيف ZIP يحوي أرشيف ZIP لكل ملاحظة، بداخله note.json
/// (العنوان، النص، التصنيف، الوسوم، المفضلة، التثبيت، التواريخ...) ومرفقاتها.
class EasyNotesImporter {
  EasyNotesImporter(this.noteRepo, this.categoryRepo);

  final NoteRepository noteRepo;
  final CategoryRepository categoryRepo;

  static const _palette = [
    0xFF42A5F5, 0xFF7E57C2, 0xFFEF5350, 0xFF26A69A,
    0xFFFFA726, 0xFF66BB6A, 0xFFEC407A, 0xFF8D6E63,
  ];

  Future<EasyNotesImportResult> importBackup(
    Uint8List bytes, {
    bool includeTrashed = false,
  }) async {
    Archive outer;
    try {
      outer = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return EasyNotesImportResult(
          success: false, message: 'تعذّر قراءة الملف — تأكّد أنه نسخة Easy Notes.');
    }

    final existing = await categoryRepo.getAll();
    final catByName = <String, int>{for (final c in existing) c.name: c.id!};
    var colorIdx = existing.length;
    var imported = 0, skipped = 0, newCats = 0;

    Future<int?> ensureCategory(String? name) async {
      final n = name?.trim() ?? '';
      if (n.isEmpty) return null;
      if (catByName.containsKey(n)) return catByName[n];
      final id = await categoryRepo.insert(Category(
        name: n,
        color: _palette[colorIdx++ % _palette.length],
        iconCode: 7,
        position: catByName.length,
      ));
      catByName[n] = id;
      newCats++;
      return id;
    }

    for (final entry in outer.files) {
      if (!entry.isFile || !entry.name.toLowerCase().endsWith('.zip')) continue;
      try {
        final inner = ZipDecoder().decodeBytes(entry.content as List<int>);
        final noteFile = inner.findFile('note.json');
        if (noteFile == null) continue;
        final d = jsonDecode(utf8.decode(noteFile.content as List<int>))
            as Map<String, dynamic>;

        final trashed = d['trashed'] == true;
        if (trashed && !includeTrashed) {
          skipped++;
          continue;
        }

        final title = (d['title'] as String?)?.trim() ?? '';
        final content = (d['content'] as String?) ?? '';
        if (title.isEmpty && content.trim().isEmpty) {
          skipped++;
          continue;
        }

        int? catId;
        final bc = d['baseCategory'];
        if (bc is Map && bc['name'] is String) {
          catId = await ensureCategory(bc['name'] as String);
        }

        final tags = ((d['tags'] as String?) ?? '')
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        final imagePath = await _extractFirstImage(inner, d['attachmentsList']);

        final created = _ms(d['creation']) ?? DateTime.now();
        final note = Note(
          title: title,
          content: content,
          type: imagePath != null ? NoteType.image : NoteType.text,
          isFavorite: _truthy(d['favorite']),
          isPinned: _truthy(d['isPined']),
          isArchived: d['archived'] == true,
          isDeleted: trashed,
          isLocked: d['locked'] == true,
          categoryId: catId,
          imagePath: imagePath,
          createdAt: created,
          updatedAt: _ms(d['lastModification']) ?? created,
          tags: tags,
        );
        await noteRepo.insertNote(note);
        imported++;
      } catch (_) {
        skipped++;
      }
    }

    return EasyNotesImportResult(
      success: imported > 0,
      imported: imported,
      skipped: skipped,
      newCategories: newCats,
      message: imported > 0
          ? 'تم استيراد $imported ملاحظة و$newCats تصنيف.'
          : 'لم يتم استيراد أي ملاحظة.',
    );
  }

  Future<String?> _extractFirstImage(Archive inner, dynamic attachmentsList) async {
    if (attachmentsList is! List) return null;
    for (final a in attachmentsList) {
      if (a is! Map) continue;
      final mime = a['mime_type']?.toString() ?? '';
      if (!mime.startsWith('image/')) continue;
      final name = a['name']?.toString();
      ArchiveFile? img = (name != null) ? inner.findFile(name) : null;
      img ??= inner.files
          .where((f) => f.isFile && f.name != 'note.json' && _isImage(f.name))
          .cast<ArchiveFile?>()
          .firstWhere((_) => true, orElse: () => null);
      if (img != null) {
        try {
          final path = await FileService.instance.newAttachmentPath(_ext(img.name));
          await File(path).writeAsBytes(img.content as List<int>);
          return path;
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  bool _truthy(dynamic v) => v == 1 || v == true || v == '1';

  DateTime? _ms(dynamic v) =>
      (v is int && v > 0) ? DateTime.fromMillisecondsSinceEpoch(v) : null;

  bool _isImage(String n) {
    final l = n.toLowerCase();
    return l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.png') ||
        l.endsWith('.webp');
  }

  String _ext(String n) {
    final i = n.lastIndexOf('.');
    return i >= 0 ? n.substring(i) : '.jpg';
  }
}
