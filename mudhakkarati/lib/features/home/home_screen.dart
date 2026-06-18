import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/text/line_direction.dart';
import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/note.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/note_actions.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/note_card.dart';
import '../../services/backup_service.dart';
import '../../services/sync/sync_service.dart';
import '../backup/backup_screen.dart';
import '../calendar/calendar_screen.dart';
import '../reminders/reminders_provider.dart';
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
  bool _searching = false; // حقل البحث مخفيّ حتى يُفتح بأيقونة العدسة
  bool _restoreChecked = false; // بحث تلقائي عن نسخة احتياطية مرّة واحدة
  bool _backupReminderChecked = false; // فحص تذكير النسخة الخارجية مرّة واحدة
  bool _showBackupReminder = false; // إظهار شريط «صدّر نسخة قبل التحديث»

  /// يفحص (مرّة واحدة لكل دخول) إن كان يجب تذكير المستخدم بنسخة خارجية.
  Future<void> _maybeShowBackupReminder() async {
    final need = await BackupService.instance.needsExternalBackupReminder();
    if (mounted && need) setState(() => _showBackupReminder = true);
  }

  /// عند فراغ الملاحظات: يبحث تلقائيًا عن أحدث نسخة محفوظة ويعرض استعادتها.
  /// [manual] = من زرّ المستخدم (يفتح منتقي الملفات إن لم توجد نسخة داخلية).
  Future<void> _offerRestore({bool manual = false}) async {
    final file = await BackupService.instance.latestAutoBackup();
    if (!mounted) return;
    if (file == null) {
      // لا نسخة داخلية — إن كان طلبًا يدويًا نفتح شاشة النسخ لاختيار ملف.
      if (manual) {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BackupScreen()));
        if (mounted) await context.read<NotesProvider>().init();
      }
      return;
    }
    // العرض التلقائي: لا يظهر إلا إذا كانت القائمة **فعلًا** فارغة، والشاشة
    // الرئيسية هي الظاهرة (تفاديًا لظهوره أثناء التحميل أو فوق شاشة أخرى مثل
    // المفضّلة). الطلب اليدوي يتجاوز هذه الشروط.
    if (!manual) {
      final notes = context.read<NotesProvider>();
      // فلتر/بحث نشط قد يُفرغ القائمة رغم وجود ملاحظات ⇒ ليست قاعدة فارغة فعلًا.
      final filtering = notes.filterCategoryId != null ||
          notes.filterTag != null ||
          notes.search.trim().isNotEmpty ||
          notes.hasAdvancedFilter;
      if (notes.loading || notes.items.isNotEmpty || filtering) return;
      // لا يظهر إلا والشاشة الرئيسية هي الظاهرة (لا فوق المفضّلة أو غيرها).
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    }
    final stamp = file.path.split('/').last;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: const Text('استعادة نسخة احتياطية؟'),
        content: Text('وُجدت نسخة محفوظة:\n$stamp\nهل تريد استعادة ملاحظاتك منها؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لاحقًا')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استعادة')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await BackupService.instance.restoreAutoBackup(file);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(r.message)));
    if (r.success) {
      await context.read<NotesProvider>().init();
      if (mounted) await context.read<RemindersProvider>().refresh();
      // أعد جدولة التذكيرات المستعادة فورًا كي تعمل دون انتظار إعادة التشغيل.
      if (mounted) await context.read<RemindersProvider>().ensureScheduled();
    }
  }

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

  /// زر + : قائمة إضافة سريعة عصرية (شبكة بطاقات ثلاثية الأبعاد).
  Future<void> _quickAdd() async {
    final s = S.of(context);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        // (أيقونة، تسمية، لون، إجراء) لكل نوع إضافة — مكان واحد لكل الأنواع.
        final items = <(IconData, String, Color, VoidCallback)>[
          (Icons.edit_note, s.t('qa_note'), const Color(0xFF42A5F5),
              () => _quickType(NoteType.text)),
          (Icons.checklist, s.t('note_checklist'), const Color(0xFF66BB6A),
              () => _quickSmooth(startAsTask: true)),
          (Icons.mic, s.t('qa_audio'), const Color(0xFFEF5350),
              () => _quickType(NoteType.audio)),
          (Icons.image, s.t('qa_image'), const Color(0xFFAB47BC),
              () => _quickType(NoteType.image)),
          (Icons.picture_as_pdf, s.t('note_pdf'), const Color(0xFFD32F2F),
              () => _quickType(NoteType.pdf)),
          (Icons.brush, s.t('note_drawing'), const Color(0xFF8E24AA),
              () => _quickType(NoteType.drawing)),
          (Icons.vpn_key, s.t('note_password'), const Color(0xFF00897B),
              () => _addTypedNote(NoteType.password)),
          (Icons.dashboard_customize_outlined, s.t('qa_template'),
              const Color(0xFFFFA726), () => showTemplatePicker(context)),
          (Icons.today, s.t('qa_today'), const Color(0xFF5C6BC0), _openDaily),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ترويسة بزرّ رجوع/إغلاق واضح.
                Row(
                  children: [
                    IconButton(
                      tooltip: 'رجوع',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                    Text(s.t('qa_title'),
                        style: Theme.of(sheetCtx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    for (final it in items)
                      _quickCard(sheetCtx, it.$1, it.$2, it.$3, it.$4),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// بطاقة إضافة سريعة عصرية (أيقونة متدرّجة ثلاثية الأبعاد + تسمية).
  Widget _quickCard(BuildContext sheetCtx, IconData icon, String label,
      Color color, VoidCallback action) {
    final scheme = Theme.of(sheetCtx).colorScheme;
    final dark = Theme.of(sheetCtx).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1E2230) : Colors.white;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.pop(sheetCtx);
        action();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [surface, Color.alphaBlend(color.withOpacity(0.07), surface)],
          ),
          border: Border.all(color: color.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.4 : 0.08),
                offset: const Offset(0, 6),
                blurRadius: 14,
                spreadRadius: -4),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            gradientBadge(icon, color, size: 46, radius: 14, iconSize: 24),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface)),
            ),
          ],
        ),
      ),
    );
  }

  /// المحرّر السلس (قائمة أسطر بمحاذاة تلقائية + مربعات اختيارية).
  /// [startAsTask] = يبدأ السطر الأول كمهمة (قائمة مهام) أو نصًّا (ملاحظة عامة).
  Future<void> _quickSmooth({required bool startAsTask}) async {
    final provider = context.read<NotesProvider>();
    final catId = provider.inboxId ?? provider.filterCategoryId;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          initialType: NoteType.checklist,
          initialCategoryId: catId,
          startAsTask: startAsTask,
        ),
      ),
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
        // أنواع الإضافة جميعها في زرّ (+) — لا نكرّرها هنا.
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

    // عند وجود ملاحظات، نفحص (مرّة) إن حان وقت تذكير النسخة الخارجية.
    if (!_backupReminderChecked &&
        !provider.loading &&
        provider.items.isNotEmpty) {
      _backupReminderChecked = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _maybeShowBackupReminder());
    }

    return Scaffold(
      drawer: const AppDrawer(),
      // زر + يفتح قائمة الخيارات (ملاحظة/قائمة مهام/صوت/صورة...).
      floatingActionButton: FloatingActionButton(
        onPressed: _quickAdd,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context, s, settings, provider)),
              SliverToBoxAdapter(child: _syncBanner(context)),
              if (_showBackupReminder)
                SliverToBoxAdapter(child: _backupReminderBanner(context)),
              if (provider.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.dbError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _readError(context),
                )
              else if (provider.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _empty(context, s, provider),
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

  /// شريط مزامنة خفيف في الأعلى (يظهر فقط أثناء/بعد المزامنة ثم يختفي).
  Widget _syncBanner(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.status,
      builder: (context, st, _) {
        final scheme = Theme.of(context).colorScheme;
        Widget child;
        if (st.state == SyncUi.idle) {
          child = const SizedBox(width: double.infinity);
        } else {
          late final Widget leading;
          late final Color color;
          switch (st.state) {
            case SyncUi.syncing:
              leading = const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2));
              color = scheme.primary;
              break;
            case SyncUi.done:
              leading =
                  const Icon(Icons.cloud_done, size: 18, color: Colors.green);
              color = Colors.green.shade700;
              break;
            case SyncUi.error:
              leading = Icon(Icons.cloud_off, size: 18, color: scheme.error);
              color = scheme.error;
              break;
            case SyncUi.idle:
              leading = const SizedBox.shrink();
              color = scheme.primary;
              break;
          }
          child = Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    st.message,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }

  /// شريط بارز يُذكّر بأخذ نسخة احتياطية خارجية قبل التحديث (يحمي من فقدان
  /// الملاحظات عند إلغاء التثبيت/فقدان الجهاز). يظهر فقط عند الحاجة.
  Widget _backupReminderBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('احمِ ملاحظاتك',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onTertiaryContainer)),
                Text('صدّر نسخة احتياطية (سحابة/ملف) قبل أي تحديث.',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onTertiaryContainer.withOpacity(0.85))),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BackupScreen()));
              // قد يكون صدّر نسخة — أعد الفحص فإن لم تَعُد هناك حاجة نُخفي الشريط.
              if (!mounted) return;
              final need =
                  await BackupService.instance.needsExternalBackupReminder();
              if (mounted) setState(() => _showBackupReminder = need);
            },
            child: const Text('صدّر الآن'),
          ),
          IconButton(
            tooltip: 'لاحقًا',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close,
                size: 20, color: scheme.onTertiaryContainer),
            onPressed: () async {
              await BackupService.instance.snoozeExternalBackupReminder();
              if (mounted) setState(() => _showBackupReminder = false);
            },
          ),
        ],
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
              // الاسم نُقل للقائمة الجانبية و«حول التطبيق»؛ نُبقي الشريط غير مزدحم
              // كي تبقى أيقونة القائمة (☰) ظاهرة. (المفضّلة/المعلومات في القائمة الجانبية.)
              const Spacer(),
              IconButton(
                tooltip: s.t('search_hint'),
                icon: Icon(_searching ? Icons.search_off : Icons.search),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _searchCtrl.clear();
                    provider.setSearch('');
                  }
                }),
              ),
              IconButton(
                tooltip: s.t('calendar'),
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalendarScreen())),
              ),
              IconButton(
                tooltip: s.t('reminders'),
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
          // حقل البحث يظهر فقط عند فتح العدسة (يوفّر مساحة فوق الملاحظات).
          if (_searching) ...[
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (ctx, setSearchState) => TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) {
                  provider.setSearch(v);
                  setSearchState(() {}); // اتجاه الحقل فورًا (دون إعادة بناء القائمة)
                },
                textDirection: lineDirection(_searchCtrl.text),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: s.t('search_hint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: s.t('advanced_search'),
                        icon: Icon(Icons.tune,
                            color: provider.hasAdvancedFilter
                                ? Theme.of(context).colorScheme.primary
                                : null),
                        onPressed: () => showAdvancedFilter(context),
                      ),
                      IconButton(
                        tooltip: 'إغلاق البحث',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          provider.setSearch('');
                          _searching = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

  /// حالة «تعذّر فتح البيانات» (غالبًا مؤقّت) — **لا** نعرضها كفارغة ولا نقترح
  /// الاستعادة (حماية من قرار خاطئ). نطمئن المستخدم ونتيح إعادة المحاولة.
  Widget _readError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.errorContainer.withOpacity(0.5),
              ),
              child: Icon(Icons.lock_clock_outlined,
                  size: 56, color: scheme.error),
            ),
            const SizedBox(height: 18),
            const Text('تعذّر فتح بياناتك مؤقّتًا',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'ملاحظاتك محفوظة ولم تُحذف — حدث تعذّر مؤقّت في قراءة بياناتك '
              'المشفّرة. أعد فتح التطبيق أو اضغط «إعادة المحاولة».',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).hintColor, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () async {
                await AppDatabase.instance.reopen();
                if (mounted) await context.read<NotesProvider>().init();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, S s, NotesProvider provider) {
    // فراغ بسبب مُرشِّح/بحث (تصنيف/وسم/بحث) — ملاحظاتك موجودة، فلا نُظهر شاشة
    // «لا ملاحظات» المخيفة ولا الاستعادة؛ بل رسالة لطيفة + زرّ «إظهار الكل».
    final filtering = provider.filterCategoryId != null ||
        provider.filterTag != null ||
        provider.search.trim().isNotEmpty ||
        provider.hasAdvancedFilter;
    if (filtering) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_off_outlined,
                  size: 60, color: scheme.outline),
              const SizedBox(height: 14),
              const Text('لا توجد ملاحظات بهذا المُرشِّح',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('ملاحظاتك محفوظة — جرّب «الكل» أو امسح البحث.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).hintColor, fontSize: 12.5)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  provider.setCategoryFilter(null); // يمسح التصنيف والوسم
                  provider.clearAdvancedFilter();
                  _searchCtrl.clear();
                  provider.setSearch('');
                },
                icon: const Icon(Icons.grid_view),
                label: const Text('إظهار الكل'),
              ),
            ],
          ),
        ),
      );
    }

    // فراغ حقيقي (لا ملاحظات إطلاقًا): عرض الاستعادة كشبكة أمان.
    if (!_restoreChecked) {
      _restoreChecked = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _offerRestore());
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة دائرية بتدرّج ناعم — متناسقة مع مظهر التطبيق العصري.
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withOpacity(0.55),
                    scheme.primaryContainer.withOpacity(0.18),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                      color: scheme.primary.withOpacity(0.18),
                      offset: const Offset(0, 10),
                      blurRadius: 24,
                      spreadRadius: -6),
                ],
              ),
              child: Icon(Icons.sticky_note_2_outlined,
                  size: 64, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(s.t('empty_notes'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(s.t('empty_notes_hint'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _offerRestore(manual: true),
              icon: const Icon(Icons.restore),
              label: const Text('استعادة من نسخة احتياطية'),
            ),
          ],
        ),
      ),
    );
  }

}
