import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/note.dart';
import '../../widgets/ui_kit.dart';
import '../editor/note_editor_screen.dart';
import '../home/notes_provider.dart';
import '../reminders/reminders_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  bool _hijri = false;

  List<Note> _all = [];
  bool _loading = true;

  static const _kHijriPref = 'calendar_hijri'; // تذكّر اختيار التقويم

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadHijriPref();
  }

  Future<void> _loadHijriPref() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _hijri = p.getBool(_kHijriPref) ?? false);
  }

  Future<void> _setHijri(bool v) async {
    setState(() => _hijri = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHijriPref, v);
  }

  /// نقل الشهر **الهجريّ** المعروض بمقدار [delta] (±1) مع ضبط السنة.
  void _shiftHijriMonth(int delta) {
    final hf = HijriCalendar.fromDate(_focused);
    var y = hf.hYear;
    var m = hf.hMonth + delta;
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    setState(() => _focused = HijriCalendar().hijriToGregorian(y, m, 1));
  }

  Future<void> _loadNotes() async {
    final provider = context.read<NotesProvider>();
    final notes = await provider.notes.getNotes();
    if (mounted) {
      setState(() {
        _all = notes;
        _loading = false;
      });
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Note> _notesFor(DateTime day) =>
      _all.where((n) => _sameDay(n.createdAt, day)).toList();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // أسماء الشهور/الأيام الهجريّة حسب لغة الواجهة.
    HijriCalendar.setLocal(s.isArabic ? 'ar' : 'en');
    final reminders = context.watch<RemindersProvider>();
    final dayNotes = _notesFor(_selected);
    final dayReminders = reminders.items
        .where((v) => _sameDay(v.reminder.time, _selected))
        .toList();

    return Scaffold(
      appBar: gradientAppBar(context, s.t('calendar'), actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(s.t('gregorian'))),
                ButtonSegment(value: true, label: Text(s.t('hijri'))),
              ],
              selected: {_hijri},
              onSelectionChanged: (v) => _setHijri(v.first),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotes,
              child: ListView(
                children: [
                  // التقويم بالكامل: هجريّ (شبكة مخصّصة) أو ميلاديّ (TableCalendar).
                  if (_hijri)
                    _hijriCalendar(context, s)
                  else
                    TableCalendar<Note>(
                      locale: s.isArabic ? 'ar' : 'en',
                      firstDay: DateTime(2015),
                      lastDay: DateTime(2100),
                      focusedDay: _focused,
                      selectedDayPredicate: (d) => _sameDay(d, _selected),
                      eventLoader: _notesFor,
                      startingDayOfWeek: StartingDayOfWeek.saturday,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {CalendarFormat.month: ''},
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selected = selected;
                          _focused = focused;
                        });
                      },
                      calendarStyle: CalendarStyle(
                        markerDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  _dateHeader(context, s),
                  if (dayReminders.isNotEmpty) ...[
                    _label(context, s.t('reminders')),
                    ...dayReminders.map((v) => ListTile(
                          leading: const Icon(Icons.alarm),
                          title: Text(v.note?.title.isNotEmpty == true
                              ? v.note!.title
                              : 'ملاحظة'),
                          subtitle:
                              Text(DateFormat('HH:mm').format(v.reminder.time)),
                        )),
                  ],
                  _label(context, s.t('nav_notes')),
                  if (dayNotes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(s.t('no_notes_day'))),
                    )
                  else
                    ...dayNotes.map((n) => ListTile(
                          leading: const Icon(Icons.sticky_note_2_outlined),
                          title: Text(
                            n.title.isNotEmpty ? n.title : n.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoteEditorScreen(noteId: n.id),
                            ),
                          ),
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// شبكة تقويم **هجريّة كاملة**: رأس باسم الشهر الهجريّ + تنقّل بالشهور الهجريّة،
  /// وخلايا بأرقام الأيام الهجريّة (مع علامة الملاحظات وتمييز اليوم/المحدَّد).
  /// كل خليّة مرتبطة بتاريخها الميلاديّ المقابل كي تعمل الملاحظات والاختيار كالعادة.
  Widget _hijriCalendar(BuildContext context, S s) {
    final scheme = Theme.of(context).colorScheme;
    final hf = HijriCalendar.fromDate(_focused);
    final y = hf.hYear;
    final m = hf.hMonth;
    final firstGreg = HijriCalendar().hijriToGregorian(y, m, 1);
    final daysInMonth = HijriCalendar().getDaysInMonth(y, m);
    // أعمدة تبدأ السبت: السبت=0 … الجمعة=6 (weekday: الاثنين=1 … الأحد=7).
    final lead = (firstGreg.weekday + 1) % 7;
    final now = DateTime.now();

    final weekdays = s.isArabic
        ? const ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة']
        : const ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final greg = DateTime(firstGreg.year, firstGreg.month, firstGreg.day)
          .add(Duration(days: d - 1));
      final isToday = _sameDay(greg, now);
      final isSel = _sameDay(greg, _selected);
      final hasNotes = _notesFor(greg).isNotEmpty;
      cells.add(GestureDetector(
        onTap: () => setState(() {
          _selected = greg;
          _focused = greg;
        }),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSel
                ? scheme.primary
                : isToday
                    ? scheme.primaryContainer
                    : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$d',
                  style: TextStyle(
                      color: isSel ? scheme.onPrimary : null,
                      fontWeight: isToday || isSel ? FontWeight.bold : null)),
              if (hasNotes)
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSel ? scheme.onPrimary : scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftHijriMonth(-1),
              ),
              Text('${hf.longMonthName} $y هـ',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftHijriMonth(1),
              ),
            ],
          ),
        ),
        Row(
          children: weekdays
              .map((w) => Expanded(
                    child: Center(
                      child: Text(w,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: cells,
        ),
      ],
    );
  }

  Widget _dateHeader(BuildContext context, S s) {
    final greg = DateFormat('EEEE، d MMMM yyyy', s.isArabic ? 'ar' : 'en')
        .format(_selected);
    final h = HijriCalendar.fromDate(_selected);
    final hijriStr = '${h.hDay} ${h.longMonthName} ${h.hYear} هـ';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_hijri ? hijriStr : greg,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(_hijri ? greg : hijriStr,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).hintColor)),
    );
  }
}
