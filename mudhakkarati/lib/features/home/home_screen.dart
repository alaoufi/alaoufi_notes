import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/note_actions.dart';
import '../../widgets/note_card.dart';
import '../../widgets/type_picker_sheet.dart';
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

  Future<void> _addNote() async {
    final type = await showTypePicker(context);
    if (type == null || !mounted) return;
    // ملاحظات كلمات المرور تتطلب رقمًا سريًا أولًا (محتوى محمي).
    if (type == NoteType.password) {
      final ok = await ensurePinConfigured(context);
      if (!ok || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(initialType: type)),
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
                SliverToBoxAdapter(child: _notesBody(context, settings, provider)),
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

  Widget _notesBody(
    BuildContext context,
    SettingsProvider settings,
    NotesProvider provider,
  ) {
    final s = S.of(context);
    final pinned = provider.pinned;
    final others = provider.unpinned;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pinned.isNotEmpty) ...[
            _sectionLabel(context, s.t('pinned')),
            _grid(context, settings, provider, pinned),
            if (others.isNotEmpty) _sectionLabel(context, s.t('others')),
          ],
          _grid(context, settings, provider, others),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).hintColor)),
    );
  }

  Widget _grid(
    BuildContext context,
    SettingsProvider settings,
    NotesProvider provider,
    List<Note> notes,
  ) {
    if (notes.isEmpty) return const SizedBox.shrink();

    Widget cardFor(Note n) => NoteCard(
          note: n,
          category: provider.categoryById(n.categoryId),
          onTap: () => _openNote(n),
          onLongPress: () => showNoteActions(context, n),
        );

    if (settings.layout == NoteLayout.list) {
      return Column(
        children: notes
            .map((n) => Padding(
                  padding: const EdgeInsets.all(6),
                  child: cardFor(n),
                ))
            .toList(),
      );
    }

    // عرض شبكي بعمودين (Masonry بسيط).
    final left = <Note>[];
    final right = <Note>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }
    Widget column(List<Note> col) => Expanded(
          child: Column(
            children: col
                .map((n) => Padding(
                      padding: const EdgeInsets.all(6),
                      child: cardFor(n),
                    ))
                .toList(),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [column(left), column(right)],
    );
  }
}
