import 'package:flutter/widgets.dart';

/// تحديد اتجاه السطر حسب **أول حرف قويّ** فيه (عربي/لاتيني)، مع **تجاهل**:
/// الأرقام، والرموز (- _ * • . , : ; ( ) [ ] { } " ' / \ …)، والمسافات في البداية.
///
/// - أول حرف عربي ⇒ RTL.
/// - أول حرف لاتيني ⇒ LTR.
/// - الأرقام في البداية تُتجاوز ويُفحص أول حرف نصّي بعدها.
/// - إن لم يوجد حرف قويّ (فارغ/رموز/أرقام فقط) ⇒ [fallback] (افتراضيًّا RTL).
///
/// يُستخدم لتحديد اتجاه الكتابة والعرض لكل سطر بشكل مستقلّ دون تغيير النص المخزَّن.
TextDirection lineDirection(String text,
    {TextDirection fallback = TextDirection.rtl}) {
  for (final r in text.runes) {
    // العربية/العبرية وأشكال العربية التقديمية.
    if ((r >= 0x0590 && r <= 0x08FF) ||
        (r >= 0xFB1D && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    // اللاتينية الأساسية والممتدة.
    if ((r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A) ||
        (r >= 0xC0 && r <= 0x24F)) {
      return TextDirection.ltr;
    }
    // غير ذلك (أرقام/رموز/مسافات) ⇒ تجاهل وتابع للحرف التالي.
  }
  return fallback;
}

/// عنصر نصّ يعرض كل سطر باتجاهه المستقلّ (للعرض للقراءة فقط: البطاقات/المعاينات).
/// يحافظ على ترتيب الرموز/الشرطة/الترقيم في بداية كل سطر دون عكسها.
class AutoDirText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  const AutoDirText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    // سطر واحد: عنصر نصّ واحد باتجاهه (أبسط وأخفّ).
    if (lines.length <= 1) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: lineDirection(text),
      );
    }
    // أسطر متعددة: كل سطر باتجاهه المستقلّ.
    final shown = (maxLines != null && maxLines! < lines.length)
        ? lines.sublist(0, maxLines!)
        : lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in shown)
          Text(
            line,
            style: style,
            maxLines: 1,
            overflow: overflow ?? TextOverflow.ellipsis,
            textDirection: lineDirection(line),
          ),
      ],
    );
  }
}

// إعادة تشغيل البناء للتحقق من توفّر خوادم CI
// محاولة بناء جديدة
