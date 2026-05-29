import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/checklist_item.dart';
import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import '../../data/models/password_entry.dart';
import '../../services/secure_screen.dart';
import '../../services/vault_service.dart';
import 'password_form.dart';
import '../../widgets/color_picker_sheet.dart';
import '../../widgets/note_actions.dart';
import '../drawing/drawing_screen.dart';
import '../home/notes_provider.dart';
import '../reminders/reminder_dialog.dart';
import 'editor_attachments.dart';

/// محرّر الملاحظة لكل الأنواع، مع حفظ تلقائي أثناء الكتابة.
class NoteEditorScreen extends StatefulWidget {
  final int? noteId;
  final NoteType initialType;
  final int? initialCategoryId;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.initialType = NoteType.text,
    this.initialCategoryId,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  late Note _note;
  List<ChecklistItem> _checklist = [];
  final List<TextEditingController> _itemCtrls = [];
  PasswordEntry _passwordEntry = const PasswordEntry();

  Timer? _debounce;
  bool _loaded = false;
  bool _dirty = false;
  bool _drawingPrompted = false;
  bool _secured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<NotesProvider>();
    await VaultService.instance.ensureKey();
    if (widget.noteId != null) {
      final n = await provider.notes.getNote(widget.noteId!);
      if (n != null) {
        _note = n;
        _titleCtrl.text = n.title;
        _contentCtrl.text = n.content;
        if (n.type == NoteType.checklist) {
          _checklist = await provider.notes.getChecklist(n.id!);
          if (_checklist.isEmpty) _checklist = [ChecklistItem(noteId: n.id!, text: '')];
          _rebuildItemCtrls();
        } else if (n.type == NoteType.password) {
          _passwordEntry = PasswordEntry.fromStoredJson(n.content);
        }
      } else {
        _note = Note.create(type: widget.initialType);
      }
    } else {
      _note = Note.create(
          type: widget.initialType, categoryId: widget.initialCategoryId);
      if (_note.type == NoteType.checklist) {
        _checklist = [const ChecklistItem(noteId: 0, text: '')];
        _rebuildItemCtrls();
      } else if (_note.type == NoteType.password) {
        // ملاحظات كلمات المرور مقفلة افتراضيًا (تتطلب فتح القفل لعرضها).
        _note = _note.copyWith(isLocked: true);
      }
    }
    setState(() => _loaded = true);

    _titleCtrl.addListener(_onChanged);
    _contentCtrl.addListener(_onChanged);

    // منع التصوير للملاحظات الحسّاسة (سرية/كلمات مرور).
    if (_note.type == NoteType.password || _note.isLocked) {
      _secured = true;
      SecureScreen.enable();
    }
  }

  void _rebuildItemCtrls() {
    for (final c in _itemCtrls) {
      c.dispose();
    }
    _itemCtrls.clear();
    for (final item in _checklist) {
      _itemCtrls.add(TextEditingController(text: item.text));
    }
  }

  void _onChanged() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _save);
  }

  String _checklistToContent() {
    return _checklist
        .map((i) => '${i.isDone ? '[x]' : '[ ]'} ${i.text}')
        .where((l) => l.trim().length > 3)
        .join('\n');
  }

  Future<void> _save({bool force = false}) async {
    if (!_loaded) return;
    final provider = context.read<NotesProvider>();

    final title = _titleCtrl.text;
    var content = _contentCtrl.text;
    var emptyPassword = false;
    if (_note.type == NoteType.checklist) {
      // زامن النصوص من الحقول.
      for (var i = 0; i < _checklist.length && i < _itemCtrls.length; i++) {
        _checklist[i] = _checklist[i].copyWith(text: _itemCtrls[i].text);
      }
      content = _checklistToContent();
    } else if (_note.type == NoteType.password) {
      final e = _passwordEntry;
      emptyPassword = e.site.trim().isEmpty &&
          e.app.trim().isEmpty &&
          e.username.trim().isEmpty &&
          e.password.trim().isEmpty &&
          e.notes.trim().isEmpty;
      content = e.toStoredJson();
    }

    final candidate = _note.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );

    // لا تحفظ ملاحظة فارغة تمامًا.
    final isEmpty = _note.type == NoteType.password
        ? (title.trim().isEmpty && emptyPassword)
        : candidate.isEmpty;
    if (isEmpty && !force) return;

    final id = await provider.saveNote(
      candidate,
      checklist: _note.type == NoteType.checklist ? _checklist : null,
    );
    _note = candidate.copyWith(id: id);
    _dirty = false;
  }

  Future<bool> _onWillPop() async {
    _debounce?.cancel();
    if (_dirty || _note.id == null) {
      await _save();
    }
    return true;
  }

  @override
  void dispose() {
    if (_secured) SecureScreen.disable();
    _debounce?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    for (final c in _itemCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- المرفقات ----

  Future<void> _ensureSaved() async {
    if (_note.id == null) await _save(force: true);
  }

  Future<void> _attachImage() async {
    final path = await EditorAttachments.pickImage(context);
    if (path == null) return;
    setState(() => _note = _note.copyWith(imagePath: path));
    _dirty = true;
    await _save(force: true);
  }

  Future<void> _attachPdf() async {
    final path = await EditorAttachments.pickPdf();
    if (path == null) return;
    setState(() => _note = _note.copyWith(pdfPath: path));
    _dirty = true;
    await _save(force: true);
  }

  Future<void> _editDrawing() async {
    await _ensureSaved();
    if (!mounted) return;
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingScreen(existingPath: _note.drawingPath),
      ),
    );
    if (path != null) {
      setState(() => _note = _note.copyWith(drawingPath: path));
      _dirty = true;
      await _save(force: true);
    }
  }

  void _onDrawingSetup() {
    // النوع رسم لكن لا يوجد رسم بعد: افتح لوحة الرسم مرة واحدة فقط.
    if (_drawingPrompted) return;
    if (_note.type == NoteType.drawing && _note.drawingPath == null) {
      _drawingPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _editDrawing());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _onDrawingSetup();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.resolveNoteColor(_note.color, isDark);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          actions: [
            IconButton(
              tooltip: _note.isPinned ? s.t('unpin') : s.t('pin'),
              icon: Icon(_note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () async {
                await _ensureSaved();
                setState(() => _note = _note.copyWith(isPinned: !_note.isPinned));
                await context.read<NotesProvider>().togglePin(
                    _note.copyWith(isPinned: !_note.isPinned));
              },
            ),
            IconButton(
              tooltip: s.t('color'),
              icon: const Icon(Icons.palette_outlined),
              onPressed: () async {
                final res = await showColorPicker(context, _note.color);
                if (res != null) {
                  setState(() => _note = _note.copyWith(color: res.value, clearColor: res.value == null));
                  await _ensureSaved();
                  await context.read<NotesProvider>().setColor(_note, res.value);
                }
              },
            ),
            IconButton(
              tooltip: _note.isFavorite ? s.t('unfavorite') : s.t('favorite'),
              icon: Icon(_note.isFavorite ? Icons.star : Icons.star_border,
                  color: _note.isFavorite ? Colors.amber : null),
              onPressed: () async {
                await _ensureSaved();
                final updated = _note.copyWith(isFavorite: !_note.isFavorite);
                setState(() => _note = updated);
                await context.read<NotesProvider>().toggleFavorite(_note.copyWith(isFavorite: !updated.isFavorite));
              },
            ),
            IconButton(
              tooltip: s.t('reminder'),
              icon: const Icon(Icons.alarm),
              onPressed: () async {
                await _ensureSaved();
                if (mounted) await showReminderDialog(context, _note);
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () async {
                await _ensureSaved();
                if (mounted) await showNoteActions(context, _note);
                // أعد التحميل لتحديث الحالة (لون/تثبيت/قفل).
                final fresh = await context.read<NotesProvider>().notes.getNote(_note.id!);
                if (fresh != null && mounted) setState(() => _note = fresh);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: s.t('title_hint'),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
              _categorySelector(s),
              const Divider(),
              ..._typeBody(s),
              const SizedBox(height: 16),
              _tagsEditor(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categorySelector(S s) {
    final provider = context.watch<NotesProvider>();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DropdownButton<int?>(
        value: _note.categoryId,
        hint: Text(s.t('no_category')),
        underline: const SizedBox.shrink(),
        items: [
          DropdownMenuItem(value: null, child: Text(s.t('no_category'))),
          ...provider.categories.map((c) => DropdownMenuItem(
                value: c.id,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 6, backgroundColor: Color(c.color)),
                  const SizedBox(width: 8),
                  Text(c.name),
                ]),
              )),
        ],
        onChanged: (v) async {
          setState(() => _note = _note.copyWith(categoryId: v, clearCategory: v == null));
          _dirty = true;
          await _save(force: true);
        },
      ),
    );
  }

  List<Widget> _typeBody(S s) {
    switch (_note.type) {
      case NoteType.checklist:
        return _checklistBody(s);
      case NoteType.image:
        return _imageBody(s);
      case NoteType.audio:
        return _audioBody(s);
      case NoteType.pdf:
        return _pdfBody(s);
      case NoteType.drawing:
        return _drawingBody(s);
      case NoteType.password:
        return [
          PasswordForm(
            initial: _passwordEntry,
            onChanged: (entry) {
              _passwordEntry = entry;
              _onChanged();
            },
          ),
        ];
      case NoteType.text:
        return [_contentField(s)];
    }
  }

  Widget _contentField(S s) {
    return TextField(
      controller: _contentCtrl,
      maxLines: null,
      minLines: 8,
      style: const TextStyle(fontSize: 16, height: 1.5),
      decoration: InputDecoration(
        hintText: s.t('content_hint'),
        border: InputBorder.none,
        filled: false,
      ),
    );
  }

  List<Widget> _checklistBody(S s) {
    return [
      for (var i = 0; i < _checklist.length; i++)
        Row(
          key: ValueKey('item_$i'),
          children: [
            Checkbox(
              value: _checklist[i].isDone,
              onChanged: (v) {
                setState(() =>
                    _checklist[i] = _checklist[i].copyWith(isDone: v ?? false));
                _onChanged();
              },
            ),
            Expanded(
              child: TextField(
                controller: _itemCtrls[i],
                onChanged: (_) => _onChanged(),
                style: TextStyle(
                  decoration: _checklist[i].isDone
                      ? TextDecoration.lineThrough
                      : null,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                setState(() {
                  _checklist.removeAt(i);
                  _itemCtrls.removeAt(i).dispose();
                });
                _onChanged();
              },
            ),
          ],
        ),
      TextButton.icon(
        onPressed: () {
          setState(() {
            _checklist.add(ChecklistItem(noteId: _note.id ?? 0, text: ''));
            _itemCtrls.add(TextEditingController());
          });
        },
        icon: const Icon(Icons.add),
        label: Text(s.t('add_item')),
      ),
    ];
  }

  List<Widget> _imageBody(S s) {
    return [
      if (_note.imagePath != null && File(_note.imagePath!).existsSync())
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(File(_note.imagePath!), fit: BoxFit.cover),
        )
      else
        _attachButton(s.t('note_image'), Icons.add_photo_alternate, _attachImage),
      const SizedBox(height: 8),
      if (_note.imagePath != null)
        TextButton.icon(
          onPressed: _attachImage,
          icon: const Icon(Icons.edit),
          label: Text(s.t('note_image')),
        ),
      _contentField(s),
    ];
  }

  List<Widget> _audioBody(S s) {
    return [
      AudioNoteWidget(
        existingPath: _note.audioPath,
        onRecorded: (path) async {
          setState(() => _note = _note.copyWith(audioPath: path));
          _dirty = true;
          await _ensureSaved();
          await _save(force: true);
        },
      ),
      const SizedBox(height: 12),
      _contentField(s),
    ];
  }

  List<Widget> _pdfBody(S s) {
    return [
      if (_note.pdfPath != null)
        ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text(_note.pdfPath!.split('/').last,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => EditorAttachments.openFile(_note.pdfPath!),
          ),
        )
      else
        _attachButton(s.t('note_pdf'), Icons.attach_file, _attachPdf),
      const SizedBox(height: 8),
      _contentField(s),
    ];
  }

  List<Widget> _drawingBody(S s) {
    return [
      if (_note.drawingPath != null && File(_note.drawingPath!).existsSync())
        GestureDetector(
          onTap: _editDrawing,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: Colors.white,
              child: Image.file(File(_note.drawingPath!), fit: BoxFit.contain),
            ),
          ),
        )
      else
        _attachButton(s.t('drawing'), Icons.brush, _editDrawing),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: _editDrawing,
        icon: const Icon(Icons.edit),
        label: Text(s.t('drawing')),
      ),
      _contentField(s),
    ];
  }

  Widget _attachButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).dividerColor, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _tagsEditor(S s) {
    final tags = List<String>.from(_note.tags);
    final ctrl = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('tags'), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...tags.map((t) => Chip(
                  label: Text('#$t'),
                  onDeleted: () async {
                    final updated = List<String>.from(_note.tags)..remove(t);
                    setState(() => _note = _note.copyWith(tags: updated));
                    await _ensureSaved();
                    await _save(force: true);
                  },
                )),
            SizedBox(
              width: 140,
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: s.t('add_tag'),
                  isDense: true,
                ),
                onSubmitted: (value) async {
                  final v = value.trim();
                  if (v.isEmpty) return;
                  final updated = List<String>.from(_note.tags)..add(v);
                  setState(() => _note = _note.copyWith(tags: updated));
                  ctrl.clear();
                  await _ensureSaved();
                  await _save(force: true);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
