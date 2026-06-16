import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/enums.dart';
import '../../widgets/ui_kit.dart';
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

/// ورقة البحث المتقدّم — تصميم عصري ثلاثي الأبعاد: بطاقات بحدود وظلال،
/// شارة أيقونة متدرّجة، وسهم رجوع. تصفية حسب النوع/الحالة/المرفقات/التاريخ.
Future<void> showAdvancedFilter(BuildContext context) async {
  final provider = context.read<NotesProvider>();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        final dark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final surface = dark ? const Color(0xFF1E2230) : Colors.white;

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

        // بطاقة قسم ثلاثية الأبعاد (تدرّج خفيف + حدّ + ظلّ).
        Widget sectionCard(String title, IconData icon, Widget child) =>
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    surface,
                    Color.alphaBlend(scheme.primary.withOpacity(0.04), surface),
                  ],
                ),
                border:
                    Border.all(color: scheme.outlineVariant.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(dark ? 0.35 : 0.06),
                      offset: const Offset(0, 6),
                      blurRadius: 14,
                      spreadRadius: -4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: scheme.onSurface)),
                  ]),
                  const SizedBox(height: 10),
                  child,
                ],
              ),
            );

        Widget sw(String label, bool value, ValueChanged<bool> on) =>
            FilterChip(
              label: Text(label),
              selected: value,
              onSelected: (v) => setSheet(() => on(v)),
            );

        Widget dateBtn(String label, IconData icon, VoidCallback onTap) =>
            Expanded(
              child: Material(
                color: scheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(children: [
                      Icon(icon, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            );

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  offset: const Offset(0, -6),
                  blurRadius: 24,
                  spreadRadius: -4),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // مقبض السحب.
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // الترويسة: رجوع + شارة أيقونة متدرّجة + عنوان.
                    Row(children: [
                      IconButton(
                        tooltip: 'رجوع',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                      gradientBadge(Icons.tune, scheme.primary,
                          size: 42, radius: 13, iconSize: 22),
                      const SizedBox(width: 10),
                      Text('بحث متقدّم',
                          style: Theme.of(sheetCtx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ]),

                    // النوع.
                    sectionCard(
                      'النوع',
                      Icons.category_outlined,
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
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
                    ),

                    // الحالة والمرفقات.
                    sectionCard(
                      'الحالة والمرفقات',
                      Icons.label_outline,
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          sw('مفضّلة', provider.fFav,
                              (v) => provider.fFav = v),
                          sw('مثبّتة', provider.fPinned,
                              (v) => provider.fPinned = v),
                          sw('مقفلة', provider.fLocked,
                              (v) => provider.fLocked = v),
                          sw('تحتوي صورة', provider.fImage,
                              (v) => provider.fImage = v),
                          sw('تحتوي صوت', provider.fAudio,
                              (v) => provider.fAudio = v),
                          sw('تحتوي PDF', provider.fPdf,
                              (v) => provider.fPdf = v),
                        ],
                      ),
                    ),

                    // نطاق التاريخ.
                    sectionCard(
                      'نطاق التاريخ (آخر تعديل)',
                      Icons.date_range_outlined,
                      Row(children: [
                        dateBtn(
                            provider.fFrom == null
                                ? 'من'
                                : _fmt(provider.fFrom!),
                            Icons.calendar_today,
                            () => pickDate(true)),
                        const SizedBox(width: 8),
                        dateBtn(
                            provider.fTo == null ? 'إلى' : _fmt(provider.fTo!),
                            Icons.event,
                            () => pickDate(false)),
                      ]),
                    ),

                    const SizedBox(height: 18),
                    // أزرار: مسح + تطبيق (متدرّج بظلّ).
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          onPressed: () {
                            provider.clearAdvancedFilter();
                            Navigator.pop(sheetCtx);
                          },
                          child: const Text('مسح الفلاتر'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.alphaBlend(
                                    Colors.white.withOpacity(0.18),
                                    scheme.primary),
                                scheme.primary,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: scheme.primary.withOpacity(0.4),
                                  offset: const Offset(0, 6),
                                  blurRadius: 14,
                                  spreadRadius: -3),
                            ],
                          ),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            onPressed: () {
                              provider.applyAdvancedFilter();
                              Navigator.pop(sheetCtx);
                            },
                            icon: const Icon(Icons.search, size: 20),
                            label: const Text('تطبيق',
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
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
