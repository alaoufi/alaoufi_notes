import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/enums.dart';
import '../home/notes_provider.dart';

const _typeLabels = {
  NoteType.text: 'نص',
  NoteType.checklist: 'مهام',
  NoteType.image: 'صورة',
  NoteType.audio: 'صوت',
  NoteType.pdf: 'PDF',
  NoteType.drawing: 'رسم',
  NoteType.password: 'كلمة مرور',
};

/// ورقة البحث المتقدّم: تصفية حسب النوع/الحالة/المرفقات/التاريخ.
Future<void> showAdvancedFilter(BuildContext context) async {
  final provider = context.read<NotesProvider>();
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) {
        Future<void> pickDate(bool isFrom) async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: sheetCtx,
            initialDate: (isFrom ? provider.fFrom : provider.fTo) ?? now,
            firstDate: DateTime(2015),
            lastDate: DateTime(now.year + 2),
          );
          if (d != null) {
            setSheet(() {
              if (isFrom) {
                provider.fFrom = DateTime(d.year, d.month, d.day);
              } else {
                provider.fTo = DateTime(d.year, d.month, d.day, 23, 59, 59);
              }
            });
          }
        }

        Widget sw(String label, bool value, ValueChanged<bool> on) =>
            FilterChip(
              label: Text(label),
              selected: value,
              onSelected: (v) => setSheet(() => on(v)),
            );

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'رجوع',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                    Text('بحث متقدّم',
                        style: Theme.of(sheetCtx).textTheme.titleLarge),
                  ]),
                  const SizedBox(height: 8),
                  const Text('النوع'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in _typeLabels.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: provider.fType == e.key,
                          onSelected: (sel) => setSheet(
                              () => provider.fType = sel ? e.key : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('الحالة والمرفقات'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      sw('مفضّلة', provider.fFav, (v) => provider.fFav = v),
                      sw('مثبّتة', provider.fPinned, (v) => provider.fPinned = v),
                      sw('مقفلة', provider.fLocked, (v) => provider.fLocked = v),
                      sw('تحتوي صورة', provider.fImage,
                          (v) => provider.fImage = v),
                      sw('تحتوي صوت', provider.fAudio,
                          (v) => provider.fAudio = v),
                      sw('تحتوي PDF', provider.fPdf, (v) => provider.fPdf = v),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('نطاق التاريخ (آخر تعديل)'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(provider.fFrom == null
                              ? 'من'
                              : _fmt(provider.fFrom!)),
                          onPressed: () => pickDate(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                              provider.fTo == null ? 'إلى' : _fmt(provider.fTo!)),
                          onPressed: () => pickDate(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            provider.clearAdvancedFilter();
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('مسح الفلاتر'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            provider.applyAdvancedFilter();
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('تطبيق'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

String _fmt(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
