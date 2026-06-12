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
import '../reminders/reminders_screen.dart';
import '../editor/note_editor_screen.dart';
import '../info/info_list_screen.dart';
import '../search/advanced_filter.dart';
import '../templates/note_templates.dart';
import '../../services/security_service.dart';
import '../security/info_lock.dart';
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
    // قفل الملاحظة نفسها أو قفل تصنيفها يتطلب فتحًا.
    final catLocked = note.categoryId != null &&
        await SecurityService.instance.isCategoryLocked(note.categoryId!);
    if (note.isLocked || catLocked) {
      if (!mounted) return;
      final ok = await ensureUnlocked(context);
      if (!ok) return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: note.id)),
    );
  }

  /// زر + : قائمة إضافة سريعة (تذهب الملاحظة إلى «الوارد»).
  Future<void> _quickAdd() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _qa(sheetCtx, Icons.notes, 'ملاحظة نصية سريعة',
                () => _quickType(NoteType.text)),
            _qa(sheetCtx, Icons.mic, 'تسجيل صوتي سريع',
                () => _quickType(NoteType.audio)),
            _qa(sheetCtx, Icons.image, 'صورة سريعة',
                () => _quickType(NoteType.image)),
            _qa(sheetCtx, Icons.checklist, 'قائمة مهام سريعة',
                () => _quickType(NoteType.checklist)),
            const Divider(height: 1),
            _qa(sheetCtx, Icons.dashboard_customize_outlined, 'قالب جاهز',
                () => showTemplatePicker(context)),
            _qa(sheetCtx, Icons.today, 'ملاحظة اليوم', _openDaily),
          ],
        ),
      ),
    );
  }

  Widget _qa(BuildContext sheetCtx, IconData icon, String label,
      VoidCallback action) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(sheetCtx);
        action();
      },
    );
  }

  /// إضافة سريعة لنوع محدّد إلى «الوارد».
  Future<void> _quickType(NoteType type) async {
    final provider = context.read<NotesProvider>();
    final catId = provider.inboxId ?? provider.filterCategoryId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NoteEditorScreen(initialType: type, initialCategoryId: catId),
      ),
    );
  }

  /// يفتح/يُنشئ ملاحظة اليوم.
  Future<void> _openDaily() async {
    final id = await context.read<NotesProvider>().openOrCreateDaily();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: id)),
    );
  }

  /// إنشاء نوع ملاحظة محدّد (من قائمة النقاط الثلاث).
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


  Future<void> _openInfo() async {
    if (!await ensureInfoUnlocked(context)) return;
    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const InfoListScreen()));
  }

  Widget _overflowMenu(BuildContext context, S s, NotesProvider provider) {
    final settings = context.read<SettingsProvider>();
    final showInfo = settings.infoPlacement == InfoPlacement.menu;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert,
          size: 28, color: Theme.of(context).colorScheme.onSurface),
      tooltip: 'المزيد',
      onSelected: (v) {
        if (v == 'info') {
          _openInfo();
        } else if (v == 'privacy') {
          settings.setPrivacyMode(!settings.privacyMode);
        } else if (v.startsWith('type_')) {
          _addTypedNote(NoteType.values.byName(v.substring(5)));
        } else if (v.startsWith('sort_')) {
          provider.setSort(NoteSort.values.byName(v.substring(5)));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'privacy',
          child: _menuRow(
              settings.privacyMode
                  ? Icons.visibility_off
                  : Icons.visibility_outlined,
              settings.privacyMode ? 'إيقاف وضع الخصوصية' : 'وضع الخصوصية'),
        ),
        const PopupMenuDivider(),
        if (showInfo) ...[
          PopupMenuItem<String>(
              value: 'info',
              child: _menuRow(Icons.menu_book_outlined, 'معلومات')),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem<String>(
            enabled: false, child: Text('إضافة نوع آخر')),
        PopupMenuItem<String>(
            value: 'type_checklist',
            child: _menuRow(Icons.checklist, s.t('note_checklist'))),
        PopupMenuItem<String>(
            value: 'type_image',
            child: _menuRow(Icons.image, s.t('note_image'))),
        PopupMenuItem<String>(
            value: 'type_audio', child: _menuRow(Icons.mic, s.t('note_audio'))),
        PopupMenuItem<String>(
            value: 'type_pdf',
            child: _menuRow(Icons.picture_as_pdf, s.t('note_pdf'))),
        PopupMenuItem<String>(
            value: 'type_drawing',
            child: _menuRow(Icons.brush, s.t('note_drawing'))),
        PopupMenuItem<String>(
            value: 'type_password',
            child: _menuRow(Icons.vpn_key, s.t('note_password'))),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(enabled: false, child: Text('فرز حسب')),
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
    return PopupMenuItem<String>(
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsProvider>();
    final provider = context.watch<NotesProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _quickAdd,
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: settings.layout == NoteLayout.grid ? 2 : 1,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childCount: provider.items.length,
                    itemBuilder: (context, i) {
                      final n = provider.items[i];
                      return NoteCard(
                        note: n,
                        category: provider.categoryById(n.categoryId),
                        onTap: () => _openNote(n),
                        onLongPress: () => showNoteActions(context, n),
                      );
                    },
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
                  icon: Icon(Icons.menu,
                      size: 28, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              Expanded(
                child: Text(s.t('app_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: s.t('calendar'),
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalendarScreen())),
              ),
              IconButton(
                tooltip: 'التنبيهات',
                icon: const Icon(Icons.alarm),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RemindersScreen())),
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
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'بحث متقدّم',
                    icon: Icon(Icons.tune,
                        color: provider.hasAdvancedFilter
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    onPressed: () => showAdvancedFilter(context),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        provider.setSearch('');
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _categoryChips(context, s, settings, provider),
        ],
      ),
    );
  }

  Widget _categoryChips(
      BuildContext context, S s, SettingsProvider settings, NotesProvider provider) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (settings.infoPlacement == InfoPlacement.tab)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                avatar: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('معلومات'),
                onPressed: _openInfo,
              ),
            ),
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

}
