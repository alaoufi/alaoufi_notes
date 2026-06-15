import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/text/line_direction.dart';
import '../../data/database/app_database.dart';
import '../../data/models/med_dose.dart';
import '../../data/repositories/med_repository.dart';

/// وضع الدواء/العلاج: تسجيل أخذ الجرعات أو فواتها، مع سجلّ كامل ونسبة التزام.
class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final _repo = MedRepository(AppDatabase.instance);
  List<MedDose> _doses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.getAll();
    if (mounted) setState(() {
      _doses = list;
      _loading = false;
    });
  }

  Future<void> _logDose() async {
    final names = await _repo.distinctNames();
    if (!mounted) return;
    final result = await showModalBottomSheet<MedDose>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LogSheet(suggestions: names),
    );
    if (result != null) {
      await _repo.insert(result);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final taken = _doses.where((d) => d.taken).length;
    final missed = _doses.length - taken;
    final adherence = _doses.isEmpty ? 1.0 : taken / _doses.length;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('med_mode'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logDose,
        icon: const Icon(Icons.medication),
        label: Text(s.t('med_log_dose')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
              children: [
                // بطاقة الالتزام.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.health_and_safety,
                              color: scheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(s.t('adherence'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          Text('${(adherence * 100).round()}%',
                              style: TextStyle(
                                  color: adherence > 0.7
                                      ? Colors.green
                                      : (adherence > 0.4
                                          ? Colors.orange
                                          : Colors.red),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ]),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: adherence,
                            minHeight: 8,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: adherence > 0.7
                                ? Colors.green
                                : (adherence > 0.4 ? Colors.orange : Colors.red),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _metric('$taken', s.t('med_taken'), Colors.green),
                            _metric('$missed', s.t('med_missed'), Colors.red),
                            _metric('${_doses.length}', s.t('nc_total'),
                                scheme.onSurface),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_doses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: Text(s.t('no_med_log'))),
                  )
                else
                  for (final d in _doses) _doseTile(d, s),
              ],
            ),
    );
  }

  Widget _metric(String v, String label, Color color) => Column(
        children: [
          Text(v,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _doseTile(MedDose d, S s) {
    String two(int n) => n.toString().padLeft(2, '0');
    final when = '${d.at.year}/${two(d.at.month)}/${two(d.at.day)}  '
        '${two(d.at.hour)}:${two(d.at.minute)}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Icon(d.taken ? Icons.check_circle : Icons.cancel,
            color: d.taken ? Colors.green : Colors.red),
        title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            [if ((d.dose ?? '').isNotEmpty) d.dose!, when].join('  •  '),
            style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await _repo.delete(d.id!);
            await _load();
          },
        ),
      ),
    );
  }
}

/// ورقة تسجيل جرعة: اسم + جرعة + الحالة (أُخذت/فاتت).
class _LogSheet extends StatefulWidget {
  final List<String> suggestions;
  const _LogSheet({required this.suggestions});

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  bool _taken = true;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('med_log_dose'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            textDirection: lineDirection(_name.text),
            decoration: InputDecoration(
              labelText: s.t('med_name'),
              prefixIcon: const Icon(Icons.medication_outlined),
            ),
          ),
          if (widget.suggestions.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [
                for (final n in widget.suggestions.take(8))
                  ActionChip(
                      label: Text(n),
                      onPressed: () => setState(() => _name.text = n)),
              ],
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _dose,
            decoration: InputDecoration(
              labelText: s.t('med_dose'),
              prefixIcon: const Icon(Icons.science_outlined),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.check_circle),
                  label: Text(s.t('med_taken'))),
              ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.cancel),
                  label: Text(s.t('med_missed'))),
            ],
            selected: {_taken},
            onSelectionChanged: (v) => setState(() => _taken = v.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              FilledButton(
                onPressed: _name.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        MedDose(
                          name: _name.text.trim(),
                          dose: _dose.text.trim().isEmpty
                              ? null
                              : _dose.text.trim(),
                          taken: _taken,
                          at: DateTime.now(),
                        )),
                child: Text(s.t('save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
