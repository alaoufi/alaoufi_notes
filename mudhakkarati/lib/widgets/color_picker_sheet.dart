import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';

/// نتيجة اختيار لون/نمط خلفية البطاقة.
class ColorPickResult {
  final int? value; // لون (int) أو null للافتراضي
  final int? bgStyle; // 0..3 أو null إن لم يتغيّر
  const ColorPickResult(this.value, {this.bgStyle});
}

/// شيت لاختيار لون الخلفية ونمطها (سادة/مسطّر/شبكي/نقاط).
Future<ColorPickResult?> showColorPicker(
  BuildContext context,
  int? current, {
  int currentStyle = 0,
}) {
  final s = S.of(context);
  int selectedStyle = currentStyle;

  return showModalBottomSheet<ColorPickResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('color'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < AppColors.noteColorsLight.length; i++)
                      _swatch(
                        context,
                        color: AppColors.noteColorsLight[i],
                        onTap: () => Navigator.pop(
                          context,
                          ColorPickResult(
                            i == 0 ? null : AppColors.noteColorsLight[i].value,
                            bgStyle: selectedStyle,
                          ),
                        ),
                        selected: i == 0
                            ? current == null
                            : current == AppColors.noteColorsLight[i].value,
                        isReset: i == 0,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('نمط الصفحة',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final entry in const [
                      [0, 'سادة', Icons.crop_square],
                      [1, 'مسطّر', Icons.notes],
                      [2, 'شبكي', Icons.grid_on],
                      [3, 'نقاط', Icons.more_horiz],
                    ])
                      Expanded(
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
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      ColorPickResult(current, bgStyle: selectedStyle),
                    ),
                    child: Text(s.t('ok')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _swatch(
  BuildContext context, {
  required Color color,
  required VoidCallback onTap,
  required bool selected,
  bool isReset = false,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46,
      height: 46,
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
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: InkWell(
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
    ),
  );
}
