// نخفي Category الخاصة بـ Flutter (تعليق توضيحي) لتفادي التعارض مع نموذجنا.
import 'package:flutter/foundation.dart' hide Category;

import '../../data/models/category.dart';
import '../../data/models/checklist_item.dart';
import '../../data/models/note.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../services/file_service.dart';
import '../../services/widget_service.dart';

/// الحالة المركزية للملاحظات والتصنيفات.
class NotesProvider extends ChangeNotifier {
  final NoteRepository notes;
  final CategoryRepository categoriesRepo;

  NotesProvider(this.notes, this.categoriesRepo);

  List<Note> _items = [];
  List<Category> _categories = [];
  bool _loading = true;

  int? _filterCategoryId; // null = الكل
  String? _filterTag;
  String _search = '';

  List<Note> get items => _items;
  List<Category> get categories => _categories;
  bool get loading => _loading;
  int? get filterCategoryId => _filterCategoryId;
  String? get filterTag => _filterTag;
  String get search => _search;

  List<Note> get pinned => _items.where((n) => n.isPinned).toList();
  List<Note> get unpinned => _items.where((n) => !n.isPinned).toList();

  Future<void> init() async {
    await Future.wait([loadCategories(), refresh()]);
    await notes.purgeOldTrash();
  }

  Future<void> loadCategories() async {
    _categories = await categoriesRepo.getAll();
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _items = await notes.getNotes(
      categoryId: _filterCategoryId,
      tag: _filterTag,
      search: _search,
    );
    _loading = false;
    notifyListeners();
    // تحديث الويدجت بآخر/أهم ملاحظة.
    WidgetService.instance.update(_items);
  }

  Future<void> setCategoryFilter(int? categoryId) async {
    _filterCategoryId = categoryId;
    _filterTag = null;
    await refresh();
  }

  Future<void> setTagFilter(String? tag) async {
    _filterTag = tag;
    _filterCategoryId = null;
    await refresh();
  }

  Future<void> setSearch(String query) async {
    _search = query;
    await refresh();
  }

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---- إجراءات الملاحظات ----

  Future<int> saveNote(Note note, {List<ChecklistItem>? checklist}) async {
    final id = await notes.upsertNote(note);
    if (checklist != null) {
      await notes.saveChecklist(id, checklist);
    }
    await refresh();
    return id;
  }

  Future<void> togglePin(Note note) async {
    await notes.togglePin(note);
    await refresh();
  }

  Future<void> toggleFavorite(Note note) async {
    await notes.toggleFavorite(note);
    await refresh();
  }

  Future<List<Note>> getFavorites() => notes.getNotes(onlyFavorites: true);
  Future<List<Note>> getLocked() => notes.getLocked();

  Future<void> setArchived(Note note, bool archived) async {
    await notes.setArchived(note.id!, archived);
    await refresh();
  }

  Future<void> setColor(Note note, int? color) async {
    await notes.setColor(note.id!, color);
    await refresh();
  }

  Future<void> setLocked(Note note, bool locked) async {
    await notes.setLocked(note.id!, locked);
    await refresh();
  }

  Future<void> moveToTrash(Note note) async {
    await notes.moveToTrash(note.id!);
    await refresh();
  }

  Future<void> duplicate(Note note) async {
    await notes.duplicate(note.id!);
    await refresh();
  }

  // ---- التصنيفات ----

  Future<void> addCategory(Category category) async {
    await categoriesRepo.insert(category);
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await categoriesRepo.update(category);
    await loadCategories();
    await refresh();
  }

  Future<void> deleteCategory(int id) async {
    if (_filterCategoryId == id) _filterCategoryId = null;
    await categoriesRepo.delete(id);
    await loadCategories();
    await refresh();
  }

  Future<void> reorderCategories(List<Category> ordered) async {
    await categoriesRepo.reorder(ordered);
    await loadCategories();
  }

  Future<int> countByCategory(int categoryId) => notes.countByCategory(categoryId);

  // ---- سلة المحذوفات ----

  Future<List<Note>> getTrash() => notes.getTrash();
  Future<List<Note>> getArchived() => notes.getArchived();

  Future<void> restore(int id) async {
    await notes.restoreFromTrash(id);
    await refresh();
  }

  Future<void> deleteForever(Note note) async {
    // حذف المرفقات المرتبطة فعليًا من القرص.
    await FileService.instance.deleteIfExists(note.imagePath);
    await FileService.instance.deleteIfExists(note.audioPath);
    await FileService.instance.deleteIfExists(note.pdfPath);
    await FileService.instance.deleteIfExists(note.drawingPath);
    await notes.deletePermanently(note.id!);
    await refresh();
  }

  Future<void> emptyTrash() async {
    final trash = await notes.getTrash();
    for (final n in trash) {
      await FileService.instance.deleteIfExists(n.imagePath);
      await FileService.instance.deleteIfExists(n.audioPath);
      await FileService.instance.deleteIfExists(n.pdfPath);
      await FileService.instance.deleteIfExists(n.drawingPath);
    }
    await notes.emptyTrash();
    await refresh();
  }

  Future<List<String>> allTags() => notes.getAllTags();
}
