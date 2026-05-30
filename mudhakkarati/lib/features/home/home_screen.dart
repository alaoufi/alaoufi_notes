import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/note_actions.dart';
import '../../widgets/note_card.dart';
import '../calendar/calendar_screen.dart';
import '../editor/note_editor_screen.dart';
import '../security/note_unlock.dart';
import '../security/pin_setup.dart';
import '../settings/settings_provider.dart';
import 'notes_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNote(Note note) async {
    if (note.isLocked) {
      final ok = await ensureUnlocked(context);
      if (!ok) return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: note.id)),
    );
  }

  /// زر + : ملاحظة نصية عادية مباشرة في القسم المفتوح حاليًا.
  Future<void> _addNote() async {
    final catId = context.read<NotesProvider>().filterCategoryId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
            initialType: NoteType.text, initialCategoryId: catId),
      ),
    );
  }

  /// إنشاء نوع ملاحظة محدّد (من قائمة ⋮).
  Future<void> _addTypedNote(NoteType type) async {
    final catId = context.read<NotesProvider>().filterCategoryId;
    if (type == NoteType.password) {
      final ok = await ensurePinConfigured(context);
      if (!ok || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteEditorScreen(initialType: type, initialCategoryId: catId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<NotesProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        icon: const Icon(Icons.add),
        label: Text(s.t('add_note')),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context, s, settings, provider)),
              if (provider.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _empty(context, s),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount:
                        settings.layout == NoteLayout.grid ? 2 : 1,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childCount: provider.items.length,
                    itemBuilder: (context, i) =>
                        _card(context, provider.items[i]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    S s,
    SettingsProvider settings,
    NotesProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'القائمة',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Text(s.t('app_name'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                tooltip: s.t('calendar'),
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalendarScreen())),
              ),
              IconButton(
                tooltip: s.t('layout'),
                icon: Icon(settings.layout == NoteLayout.grid
                    ? Icons.view_agenda_outlined
                    : Icons.grid_view_outlined),
                onPressed: settings.toggleLayout,
              ),
              _overflowMenu(context, s, provider),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: provider.setSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: s.t('search_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        provider.setSearch('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          _categoryChips(context, s, provider),
        ],
      ),
    );
  }

  Widget _categoryChips(BuildContext context, S s, NotesProvider provider) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(
            label: s.t('all'),
            selected: provider.filterCategoryId == null && provider.filterTag == null,
            onTap: () => provider.setCategoryFilter(null),
          ),
          ...provider.categories.map((c) => _chip(
                label: c.name,
                color: Color(c.color),
                selected: provider.filterCategoryId == c.id,
                onTap: () => provider.setCategoryFilter(c.id),
              )),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: color == null
            ? null
            : CircleAvatar(backgroundColor: color, radius: 6),
      ),
    );
  }

  Widget _empty(BuildContext context, S s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              size: 90, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text(s.t('empty_notes'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(s.t('empty_notes_hint'),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Note note) {
    final provider = context.read<NotesProvider>();
    return NoteCard(
      note: note,
      category: provider.categoryById(note.categoryId),
      onTap: () => _openNote(note),
      onLongPress: () => showNoteActions(context, note),
    );
  }

  Widget _overflowMenu(BuildContext context, S s, NotesProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'المزيد',
      onSelected: (v) {
        if (v.startsWith('type_')) {
          _addTypedNote(NoteType.values.byName(v.substring(5)));
        } else if (v.startsWith('sort_')) {
          provider.setSort(NoteSort.values.byName(v.substring(5)));
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(enabled: false, child: Text('إضافة ملاحظة من نوع')),
        PopupMenuItem(
            value: 'type_checklist',
            child: _menuRow(Icons.checklist, s.t('note_checklist'))),
        PopupMenuItem(
            value: 'type_image',
            child: _menuRow(Icons.image, s.t('note_image'))),
        PopupMenuItem(
            value: 'type_audio', child: _menuRow(Icons.mic, s.t('note_audio'))),
        PopupMenuItem(
            value: 'type_pdf',
            child: _menuRow(Icons.picture_as_pdf, s.t('note_pdf'))),
        PopupMenuItem(
            value: 'type_drawing',
            child: _menuRow(Icons.brush, s.t('note_drawing'))),
        PopupMenuItem(
            value: 'type_password',
            child: _menuRow(Icons.vpn_key, s.t('note_password'))),
        const PopupMenuDivider(),
        const PopupMenuItem(enabled: false, child: Text('فرز حسب')),
        _sortItem('sort_updatedDesc', 'الأحدث تعديلًا', provider),
        _sortItem('sort_createdDesc', 'الأحدث إنشاءً', provider),
        _sortItem('sort_createdAsc', 'الأقدم إنشاءً', provider),
        _sortItem('sort_titleAsc', 'العنوان (أ-ي)', provider),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      );

  PopupMenuItem<String> _sortItem(
      String value, String label, NotesProvider provider) {
    final selected = 'sort_${provider.sort.name}' == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
