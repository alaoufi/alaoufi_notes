import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadNotes();
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
              onSelectionChanged: (v) => setState(() => _hijri = v.first),
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
