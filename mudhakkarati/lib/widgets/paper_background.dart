import 'package:flutter/material.dart';

/// خلفية ورقية للملاحظة:
/// سادة (0) / مسطّر (1) / شبكي (2) / نقاط (3) /
/// شبكة دقيقة (4) / نقاط كبيرة (5) / أسطر متقاربة (6) / مربعات كبيرة (7).
class PaperBackground extends StatelessWidget {
  final int style;
  final Color lineColor;
  final Widget child;

  const PaperBackground({
    super.key,
    required this.style,
    required this.child,
    this.lineColor = const Color(0x22000000),
  });

  @override
  Widget build(BuildContext context) {
    if (style == 0) return child;
    return CustomPaint(
      painter: _PaperPainter(style: style, color: lineColor),
      child: child,
    );
  }
}

class _PaperPainter extends CustomPainter {
  final int style;
  final Color color;
  static const double gap = 28;

  _PaperPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    switch (style) {
      case 1: // مسطّر: خطوط أفقية
        for (double y = gap; y < size.height; y += gap) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case 2: // شبكي: أفقي + رأسي
        for (double y = gap; y < size.height; y += gap) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        for (double x = gap; x < size.width; x += gap) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        break;
      case 3: // نقاط
        final dot = Paint()..color = color;
        for (double y = gap; y < size.height; y += gap) {
          for (double x = gap; x < size.width; x += gap) {
            canvas.drawCircle(Offset(x, y), 1.2, dot);
          }
        }
        break;
      case 4: // شبكة دقيقة
        const g = 16.0;
        for (double y = g; y < size.height; y += g) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        for (double x = g; x < size.width; x += g) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        break;
      case 5: // نقاط كبيرة
        final dot = Paint()..color = color;
        const g = 38.0;
        for (double y = g; y < size.height; y += g) {
          for (double x = g; x < size.width; x += g) {
            canvas.drawCircle(Offset(x, y), 2.2, dot);
          }
        }
        break;
      case 6: // أسطر متقاربة
        const g = 20.0;
        for (double y = g; y < size.height; y += g) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case 7: // مربعات كبيرة
        const g = 46.0;
        for (double y = g; y < size.height; y += g) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        for (double x = g; x < size.width; x += g) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter old) =>
      old.style != style || old.color != color;
}
