import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/app_colors.dart';

/// شيت لاختيار لون البطاقة. يعيد قيمة اللون (int) أو null للون الافتراضي.
/// عند الإلغاء يعيد سلسلة 'cancel' عبر sentinel — لذا نستخدم نتيجة منفصلة.
Future<ColorPickResult?> showColorPicker(BuildContext context, int? current) {
  final s = S.of(context);
  return showModalBottomSheet<ColorPickResult>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
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
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < AppColors.noteColorsLight.length; i++)
                    _swatch(
                      context,
                      color: AppColors.noteColorsLight[i],
                      value: i == 0 ? null : AppColors.noteColorsLight[i].value,
                      selected: i == 0
                          ? current == null
                          : current == AppColors.noteColorsLight[i].value,
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ColorPickResult {
  final int? value;
  const ColorPickResult(this.value);
}

Widget _swatch(
  BuildContext context, {
  required Color color,
  required int? value,
  required bool selected,
}) {
  return GestureDetector(
    onTap: () => Navigator.pop(context, ColorPickResult(value)),
    child: Container(
      width: 52,
      height: 52,
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
          : (value == null
              ? const Icon(Icons.format_color_reset, size: 20)
              : null),
    ),
  );
}
