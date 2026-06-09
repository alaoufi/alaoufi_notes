import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/note_gradient.dart';
import '../../data/models/checklist_item.dart';
import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import '../../data/models/password_entry.dart';
import '../../services/secure_screen.dart';
import '../../services/vault_service.dart';
import 'password_form.dart';
import '../../widgets/color_picker_sheet.dart';
import '../../widgets/note_actions.dart';
import '../../widgets/paper_background.dart';
import '../drawing/drawing_screen.dart';
import '../home/notes_provider.dart';
import '../reminders/reminder_dialog.dart';
import '../settings/settings_provider.dart';
import 'editor_attachments.dart';
import 'rich_text_field.dart';

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
  String _richContent = ''; // محتوى النص الغني (Delta JSON) لنوع النص
  RichTextController? _richCtrl; // وحدة تحكّم النص الغني (لنوع النص فقط)

  Timer? _debounce;
  Color _fgColor = Colors.black87; // لون نص المتن المناسب للخلفية الحالية
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
        } else if (n.type == NoteType.text) {
          _richContent = n.content;
        }
      } else {
        _note = Note.create(type: widget.initialType);
      }
    } else {
      // ملاحظة جديدة: طبّق الافتراضي (لون الخلفية ونمط الصفحة) من الإعدادات.
      final settings = context.read<SettingsProvider>();
      _note = Note.create(
              type: widget.initialType, categoryId: widget.initialCategoryId)
          .copyWith(
        color: settings.defaultNoteColor,
        clearColor: settings.defaultNoteColor == null,
        bgStyle: settings.defaultBgStyle,
        gradient: settings.defaultGradient,
      );
      if (_note.type == NoteType.checklist) {
        _checklist = [const ChecklistItem(noteId: 0, text: '')];
        _rebuildItemCtrls();
      } else if (_note.type == NoteType.password) {
        // ملاحظات كلمات المرور مقفلة افتراضيًا (تتطلب فتح القفل لعرضها).
        _note = _note.copyWith(isLocked: true);
      }
    }
    // وحدة تحكّم النص الغني (لنوع النص) — تُهيّأ بعد معرفة المحتوى.
    if (_note.type == NoteType.text) {
      _richCtrl = RichTextController(_richContent, (json) {
        _richContent = json;
        _onChanged();
      });
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
    var emptyRich = false;
    if (_note.type == NoteType.checklist) {
      // زامن النصوص من الحقول.
      for (var i = 0; i < _checklist.length && i < _itemCtrls.length; i++) {
        _checklist[i] = _checklist[i].copyWith(text: _itemCtrls[i].text);
      }
      content = _checklistToContent();
    } else if (_note.type == NoteType.text) {
      content = _richContent;
      emptyRich = richToPlainText(_richContent).trim().isEmpty;
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
    final bool isEmpty;
    if (_note.type == NoteType.password) {
      isEmpty = title.trim().isEmpty && emptyPassword;
    } else if (_note.type == NoteType.text) {
      isEmpty = title.trim().isEmpty && emptyRich;
    } else {
      isEmpty = candidate.isEmpty;
    }
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
    _richCtrl?.dispose();
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

    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.resolveNoteColor(_note.color, isDark);
    final grad = NoteGradient.parse(_note.gradient);
    final onBg = grad != null
        ? grad.onColor
        : (ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black87);
    _fgColor = onBg;

    final scaffold = Scaffold(
      backgroundColor: grad != null ? Colors.transparent : bg,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
          backgroundColor: grad != null ? Colors.transparent : bg,
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
                final res = await showColorPicker(context, _note.color,
                    currentStyle: _note.bgStyle,
                    currentGradient: _note.gradient,
                    currentOnLine: _note.ruleOnLine ?? settings.ruleOnLine,
                    currentThickness:
                        _note.ruleThickness ?? settings.ruleThickness,
                    currentOpacity: _note.ruleOpacity ?? settings.ruleOpacity);
                if (res != null) {
                  setState(() => _note = _note.copyWith(
                        color: res.value,
                        clearColor: res.value == null,
                        bgStyle: res.bgStyle,
                        gradient: res.gradient,
                        clearGradient: res.gradient == null,
                        ruleOnLine: res.ruleOnLine,
                        ruleThickness: res.ruleThickness,
                        ruleOpacity: res.ruleOpacity,
                      ));
                  _dirty = true;
                  await _ensureSaved();
                  await _save(force: true);
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
              tooltip: s.t('tags'),
              icon: const Icon(Icons.label_outline),
              onPressed: () => _editTags(s),
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
          child: DefaultTextStyle.merge(
            style: TextStyle(color: _fgColor),
            child: Column(
            children: [
              Expanded(
                child: _note.type == NoteType.text
                    ? _textLayout(s, onBg, settings)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _titleField(s),
                          _metaRow(s),
                          const Divider(),
                          PaperBackground(
                            style: _note.bgStyle,
                            lineColor: onBg,
                            gap: noteLineGap(settings),
                            thickness:
                                _note.ruleThickness ?? settings.ruleThickness,
                            opacity:
                                _note.ruleOpacity ?? settings.ruleOpacity,
                            onLine: _note.ruleOnLine ?? settings.ruleOnLine,
                            fontSize: settings.noteFontSize,
                            topPadding: 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _typeBody(s),
                            ),
                          ),
                        ],
                      ),
              ),
              // شريط أدوات التنسيق فوق لوحة المفاتيح مباشرة (يرتفع معها).
              if (_note.type == NoteType.text && _richCtrl != null)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: RichTextToolbar(controller: _richCtrl!),
                ),
            ],
          ),
          ),
        ),
    );

    final decorated = grad != null
        ? Container(
            decoration: BoxDecoration(gradient: grad.toGradient()),
            child: scaffold,
          )
        : scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
        if (mounted) Navigator.pop(context);
      },
      child: decorated,
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _categorySelector(S s) {
    final provider = context.watch<NotesProvider>();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DropdownButton<int?>(
        value: _note.categoryId,
        isExpanded: true,
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

  Widget _titleField(S s) => TextField(
        controller: _titleCtrl,
        style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: _fgColor),
        decoration: InputDecoration(
          hintText: s.t('title_hint'),
          border: InputBorder.none,
          filled: false,
        ),
      );

  Widget _metaRow(S s) => Row(
        children: [
          Flexible(child: _categorySelector(s)),
          const SizedBox(width: 8),
          Text(
            _formatDate(_note.updatedAt),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
        ],
      );

  /// تخطيط ملاحظة النص: العنوان ثابت بالأعلى، والمحرّر يملأ الباقي ويمرّر
  /// داخليًا (viewport) — أداء سلس حتى مع المستندات الطويلة جدًّا.
  Widget _textLayout(S s, Color onBg, SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_titleField(s), _metaRow(s), const Divider()],
          ),
        ),
        Expanded(
          child: PaperBackground(
            style: _note.bgStyle,
            lineColor: onBg,
            gap: noteLineGap(settings),
            thickness: _note.ruleThickness ?? settings.ruleThickness,
            opacity: _note.ruleOpacity ?? settings.ruleOpacity,
            onLine: _note.ruleOnLine ?? settings.ruleOnLine,
            fontSize: settings.noteFontSize,
            topPadding: 8,
            // تتحرّك الأسطر مع تمرير الكتابة وتبقى محاذية لها.
            scrollController: _richCtrl?.scroll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _richCtrl == null
                  ? const SizedBox.shrink()
                  : RichTextEditorBody(controller: _richCtrl!, expand: true),
            ),
          ),
        ),
      ],
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
        return [
          if (_richCtrl != null) RichTextEditorBody(controller: _richCtrl!),
        ];
    }
  }

  Widget _contentField(S s) {
    return TextField(
      controller: _contentCtrl,
      maxLines: null,
      minLines: 8,
      style: TextStyle(fontSize: 16, height: 1.5, color: _fgColor),
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

  /// تحرير وسوم الملاحظة في ورقة سفلية تُفتح عند الطلب فقط (لا تشغل حيّزًا دائمًا).
  Future<void> _editTags(S s) async {
    await _ensureSaved();
    if (!mounted) return;
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('tags'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (_note.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _note.tags)
                      Chip(
                        label: Text('#$t'),
                        onDeleted: () async {
                          final updated = List<String>.from(_note.tags)
                            ..remove(t);
                          _note = _note.copyWith(tags: updated);
                          await _save(force: true);
                          setSheet(() {});
                          if (mounted) setState(() {});
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: s.t('add_tag'),
                  prefixIcon: const Icon(Icons.tag),
                ),
                onSubmitted: (value) async {
                  final v = value.trim();
                  if (v.isEmpty) return;
                  final updated = List<String>.from(_note.tags)..add(v);
                  _note = _note.copyWith(tags: updated);
                  ctrl.clear();
                  await _save(force: true);
                  setSheet(() {});
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
