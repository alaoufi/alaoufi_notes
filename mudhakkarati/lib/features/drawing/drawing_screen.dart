import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/file_service.dart';
import '../../widgets/confirm_dialog.dart';

/// خطّ واحد في الرسم — يحتفظ **بلونه وسماكته الخاصّة** (تحكّم مستقلّ لكل خط).
class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke(this.points, this.color, this.width);
}

/// لوحة رسم/كتابة يدوية مخصّصة: لون وسماكة لكل خط على حدة، فرشاة وممحاة،
/// لوحة ألوان، تراجع لكل خط. تعيد مسار صورة PNG عند الحفظ.
class DrawingScreen extends StatefulWidget {
  final String? existingPath;
  const DrawingScreen({super.key, this.existingPath});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final _canvasKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  _Stroke? _current;

  Color _penColor = Colors.black;
  double _penWidth = 4;
  bool _eraser = false;
  ui.Image? _bgImage; // الرسم السابق (عند التعديل) كخلفية.

  static const _palette = [
    Colors.black,
    Color(0xFF455A64),
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF3949AB),
    Color(0xFF1E88E5),
    Color(0xFF00ACC1),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFFDD835),
    Color(0xFFFB8C00),
    Color(0xFF6D4C41),
    Color(0xFFFFFFFF),
  ];

  static const _widths = [2.0, 4.0, 8.0, 14.0, 22.0];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    if (widget.existingPath == null) return;
    try {
      final bytes = await File(widget.existingPath!).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _bgImage = frame.image);
    } catch (_) {/* تعذّر تحميل الرسم السابق — نبدأ بلوحة بيضاء */}
  }

  Color get _effectiveColor => _eraser ? Colors.white : _penColor;
  double get _effectiveWidth => _eraser ? _penWidth * 2.5 : _penWidth;

  void _start(Offset p) {
    setState(() => _current = _Stroke([p], _effectiveColor, _effectiveWidth));
  }

  void _add(Offset p) {
    if (_current == null) return;
    setState(() => _current!.points.add(p));
  }

  void _end() {
    if (_current == null) return;
    setState(() {
      _strokes.add(_current!);
      _current = null;
    });
  }

  Future<void> _save() async {
    if (_strokes.isEmpty && _bgImage == null) {
      Navigator.pop(context);
      return;
    }
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final path = await FileService.instance.newAttachmentPath('png');
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, path);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('drawing')),
        actions: [
          IconButton(
            tooltip: s.t('undo'),
            icon: const Icon(Icons.undo),
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(() => _strokes.removeLast()),
          ),
          IconButton(
            tooltip: s.t('clear'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDelete(context,
                  title: 'مسح الرسم؟',
                  message: 'سيُمسح الرسم بالكامل ولا يمكن التراجع.',
                  confirmLabel: s.t('clear'),
                  icon: Icons.delete_sweep_outlined)) {
                setState(() {
                  _strokes.clear();
                  _current = null;
                  _bgImage = null;
                });
              }
            },
          ),
          IconButton(
            tooltip: s.t('save'),
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _canvasKey,
              child: GestureDetector(
                onPanStart: (d) => _start(d.localPosition),
                onPanUpdate: (d) => _add(d.localPosition),
                onPanEnd: (_) => _end(),
                child: CustomPaint(
                  painter: _StrokePainter(_strokes, _current, _bgImage),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          _tools(context, scheme),
        ],
      ),
    );
  }

  Widget _tools(BuildContext context, ColorScheme scheme) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // فرشاة/ممحاة + سماكات سريعة.
              Row(
                children: [
                  _toolBtn(Icons.brush, !_eraser, () {
                    setState(() => _eraser = false);
                  }),
                  const SizedBox(width: 6),
                  _toolBtn(Icons.cleaning_services_outlined, _eraser, () {
                    setState(() => _eraser = true);
                  }),
                  const SizedBox(width: 12),
                  for (final w in _widths) ...[
                    _widthDot(w),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 28,
                      value: _penWidth,
                      onChanged: (v) => setState(() => _penWidth = v),
                    ),
                  ),
                ],
              ),
              // لوحة الألوان (تؤثّر على الخطوط الجديدة فقط).
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _palette.map((c) {
                    final selected = !_eraser && c.value == _penColor.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _penColor = c;
                          _eraser = false;
                        }),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? scheme.primary
                                  : (c == Colors.white
                                      ? Colors.black26
                                      : Colors.black12),
                              width: selected ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant),
        ),
        child: Icon(icon,
            size: 22, color: selected ? scheme.primary : scheme.onSurface),
      ),
    );
  }

  Widget _widthDot(double w) {
    final selected = (_penWidth - w).abs() < 0.5;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _penWidth = w),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primaryContainer : Colors.transparent,
        ),
        child: Container(
          width: w.clamp(3, 18).toDouble(),
          height: w.clamp(3, 18).toDouble(),
          decoration: const BoxDecoration(
              color: Colors.black87, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? current;
  final ui.Image? bg;
  _StrokePainter(this.strokes, this.current, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    // خلفية بيضاء (تظهر في الصورة المصدّرة).
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    // خلفية الرسم السابق (محتواة ضمن اللوحة).
    if (bg != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: bg!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    for (final st in [...strokes, if (current != null) current!]) {
      final paint = Paint()
        ..color = st.color
        ..strokeWidth = st.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (st.points.length == 1) {
        canvas.drawCircle(
            st.points.first, st.width / 2, Paint()..color = st.color);
      } else {
        final path = Path()
          ..moveTo(st.points.first.dx, st.points.first.dy);
        for (var i = 1; i < st.points.length; i++) {
          path.lineTo(st.points[i].dx, st.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}
