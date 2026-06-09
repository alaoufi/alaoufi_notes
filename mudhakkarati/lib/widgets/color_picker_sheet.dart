import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/note_gradient.dart';

/// نتيجة اختيار لون/نمط خلفية البطاقة.
class ColorPickResult {
  final int? value; // لون (int) أو null للافتراضي
  final int? bgStyle; // 0..7 أو null إن لم يتغيّر
  final String? gradient; // تدرّج مُرمَّز، أو null لخلفية سادة
  // تسطير خاص بالملاحظة (يُطبَّق عند نمط مسطّر).
  final bool? ruleOnLine;
  final double? ruleThickness;
  final double? ruleOpacity;
  final double? ruleLineHeight;
  const ColorPickResult(
    this.value, {
    this.bgStyle,
    this.gradient,
    this.ruleOnLine,
    this.ruleThickness,
    this.ruleOpacity,
    this.ruleLineHeight,
  });
}

/// أنماط خلفية الصفحة المتاحة (يطابق مؤشّرها _PaperPainter).
const _pageStyles = <List<Object>>[
  [0, 'سادة', Icons.crop_square],
  [1, 'مسطّر', Icons.notes],
  [2, 'شبكي', Icons.grid_on],
  [3, 'نقاط', Icons.more_horiz],
  [4, 'شبكة دقيقة', Icons.grid_4x4],
  [5, 'نقاط كبيرة', Icons.blur_on],
  [6, 'أسطر', Icons.drag_handle],
  [7, 'مربعات', Icons.window_outlined],
];

/// طيف ألوان واسع لخلفية الملاحظة (هادئ ومناسب للقراءة).
List<Color> _spectrum() {
  final out = <Color>[];
  // تدرّجات رمادية.
  for (final l in [1.0, 0.92, 0.82, 0.68, 0.5]) {
    out.add(HSLColor.fromAHSL(1, 0, 0, l).toColor());
  }
  // ألوان عبر الأطياف بثلاث درجات فاتحة.
  for (var h = 0; h < 360; h += 30) {
    for (final l in [0.9, 0.78, 0.62]) {
      out.add(HSLColor.fromAHSL(1, h.toDouble(), 0.7, l).toColor());
    }
  }
  return out;
}

/// شيت لاختيار لون الخلفية ونمطها مع تحكّم لوني كامل.
Future<ColorPickResult?> showColorPicker(
  BuildContext context,
  int? current, {
  int currentStyle = 0,
  String? currentGradient,
  // قيم التسطير الحالية للملاحظة (أو الافتراضي العام كقيمة ابتدائية).
  bool currentOnLine = true,
  double currentThickness = 1.0,
  double currentOpacity = 0.12,
  double currentLineHeight = 1.6,
}) {
  final s = S.of(context);
  int selectedStyle = currentStyle;
  int? selectedColor = current;

  // حالة التسطير الخاص بالملاحظة.
  bool ruleOnLine = currentOnLine;
  double ruleThickness = currentThickness.clamp(0.5, 3.0);
  double ruleOpacity = currentOpacity.clamp(0.03, 0.6);
  double ruleLineHeight = currentLineHeight.clamp(1.0, 2.6);

  // حالة التدرّج اللوني.
  final parsedGrad = NoteGradient.parse(currentGradient);
  bool useGradient = parsedGrad != null;
  List<int> gradColors =
      parsedGrad?.colors ?? [0xFF42A5F5, 0xFF7E57C2];
  int gradDir = parsedGrad?.direction ?? 2;

  return showModalBottomSheet<ColorPickResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('color'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  // الألوان السريعة (الافتراضية).
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < AppColors.noteColorsLight.length; i++)
                        _swatch(
                          context,
                          color: AppColors.noteColorsLight[i],
                          onTap: () => setSheet(() => selectedColor =
                              i == 0 ? null : AppColors.noteColorsLight[i].value),
                          selected: i == 0
                              ? selectedColor == null
                              : selectedColor ==
                                  AppColors.noteColorsLight[i].value,
                          isReset: i == 0,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('طيف الألوان',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final picked = await _showCustomColor(
                              context, selectedColor ?? 0xFFFFFFFF);
                          if (picked != null) {
                            setSheet(() => selectedColor = picked);
                          }
                        },
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('لون مخصص'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // طيف واسع للتحكم اللوني الكامل.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _spectrum())
                        _swatch(
                          context,
                          color: c,
                          size: 34,
                          onTap: () => setSheet(() => selectedColor = c.value),
                          selected: selectedColor == c.value,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('نمط الصفحة',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _pageStyles)
                        SizedBox(
                          width: 78,
                          child: _styleOption(
                            context,
                            label: entry[1] as String,
                            icon: entry[2] as IconData,
                            selected: selectedStyle == entry[0] as int,
                            onTap: () =>
                                setSheet(() => selectedStyle = entry[0] as int),
                          ),
                        ),
                    ],
                  ),
                  // ===== تسطير/تنقيط الصفحة (يظهر عند اختيار نمط غير سادة) =====
                  if (selectedStyle != 0) ...[
                    const SizedBox(height: 18),
                    Text('تسطير الصفحة',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    // تباعد الأسطر (يوسّع المسافة — مفيد للخط العربي).
                    Row(
                      children: [
                        const SizedBox(width: 96, child: Text('تباعد الأسطر')),
                        Expanded(
                          child: Slider(
                            min: 1.0,
                            max: 2.6,
                            divisions: 16,
                            label: ruleLineHeight.toStringAsFixed(2),
                            value: ruleLineHeight,
                            onChanged: (v) =>
                                setSheet(() => ruleLineHeight = v),
                          ),
                        ),
                      ],
                    ),
                    // محاذاة الكتابة (للأنماط المسطّرة فقط).
                    if (selectedStyle == 1 || selectedStyle == 6)
                      Row(
                        children: [
                          const Expanded(child: Text('محاذاة الكتابة')),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: true, label: Text('على السطر')),
                              ButtonSegment(
                                  value: false, label: Text('بين السطرين')),
                            ],
                            selected: {ruleOnLine},
                            onSelectionChanged: (v) =>
                                setSheet(() => ruleOnLine = v.first),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 96, child: Text('سماكة الأسطر')),
                        Expanded(
                          child: Slider(
                            min: 0.5,
                            max: 3.0,
                            divisions: 10,
                            label: ruleThickness.toStringAsFixed(1),
                            value: ruleThickness,
                            onChanged: (v) => setSheet(() => ruleThickness = v),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(
                            width: 96, child: Text('شفافية الأسطر')),
                        Expanded(
                          child: Slider(
                            min: 0.03,
                            max: 0.6,
                            divisions: 19,
                            label: '${(ruleOpacity * 100).round()}%',
                            value: ruleOpacity,
                            onChanged: (v) => setSheet(() => ruleOpacity = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  // ===== التدرّج اللوني =====
                  Row(
                    children: [
                      Text('تدرّج لوني',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Switch(
                        value: useGradient,
                        onChanged: (v) => setSheet(() => useGradient = v),
                      ),
                    ],
                  ),
                  if (useGradient) ...[
                    const SizedBox(height: 8),
                    // معاينة التدرّج
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                        gradient: NoteGradient(colors: gradColors, direction: gradDir)
                            .toGradient(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ألوان التدرّج (نقر لتغييره، مع إضافة/حذف لون ثالث)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < gradColors.length; i++)
                          GestureDetector(
                            onTap: () async {
                              final picked = await _showCustomColor(
                                  context, gradColors[i]);
                              if (picked != null) {
                                setSheet(() => gradColors[i] = picked);
                              }
                            },
                            onLongPress: gradColors.length > 2
                                ? () => setSheet(() => gradColors.removeAt(i))
                                : null,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Color(gradColors[i]),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black26, width: 2),
                              ),
                            ),
                          ),
                        if (gradColors.length < 3)
                          IconButton.filledTonal(
                            tooltip: 'إضافة لون',
                            onPressed: () => setSheet(
                                () => gradColors.add(0xFF26A69A)),
                            icon: const Icon(Icons.add),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('انقر اللون لتغييره • اضغط مطوّلًا لحذف لون ثالث',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    // اتجاه التدرّج
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var d = 0; d < NoteGradient.directionNames.length; d++)
                          ChoiceChip(
                            label: Text(NoteGradient.directionNames[d]),
                            selected: gradDir == d,
                            onSelected: (_) => setSheet(() => gradDir = d),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        ColorPickResult(
                          selectedColor,
                          bgStyle: selectedStyle,
                          gradient: useGradient
                              ? NoteGradient(
                                      colors: gradColors, direction: gradDir)
                                  .encode()
                              : null,
                          ruleOnLine: ruleOnLine,
                          ruleThickness: ruleThickness,
                          ruleOpacity: ruleOpacity,
                          ruleLineHeight: ruleLineHeight,
                        ),
                      ),
                      child: Text(s.t('ok')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// منتقي لون دقيق (RGB) — تحكّم لوني كامل بأي لون.
Future<int?> _showCustomColor(BuildContext context, int initial) {
  var c = Color(initial);
  double r = c.red.toDouble(), g = c.green.toDouble(), b = c.blue.toDouble();
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setD) {
        final color = Color.fromARGB(255, r.round(), g.round(), b.round());
        Widget slider(String label, double v, Color tint, ValueChanged<double> on) =>
            Row(children: [
              SizedBox(width: 18, child: Text(label)),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 255,
                  value: v,
                  activeColor: tint,
                  onChanged: (nv) => setD(() => on(nv)),
                ),
              ),
              SizedBox(width: 34, child: Text(v.round().toString())),
            ]);
        return AlertDialog(
          title: const Text('لون مخصص'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
              ),
              const SizedBox(height: 8),
              slider('R', r, Colors.red, (v) => r = v),
              slider('G', g, Colors.green, (v) => g = v),
              slider('B', b, Colors.blue, (v) => b = v),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, color.value),
              child: Text(S.of(context).t('ok')),
            ),
          ],
        );
      },
    ),
  );
}

Widget _swatch(
  BuildContext context, {
  required Color color,
  required VoidCallback onTap,
  required bool selected,
  double size = 46,
  bool isReset = false,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.black12,
          width: selected ? 3 : 1,
        ),
      ),
      child: selected
          ? Icon(Icons.check,
              size: size * 0.45,
              color: ThemeData.estimateBrightnessForColor(color) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black87)
          : (isReset ? const Icon(Icons.format_color_reset, size: 20) : null),
    ),
  );
}

Widget _styleOption(
  BuildContext context, {
  required String label,
  required IconData icon,
  required bool selected,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? scheme.primary : Colors.black12,
          width: selected ? 2 : 1,
        ),
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: selected ? scheme.primary : null),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}
