import 'dart:io';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/file_service.dart';

/// لوحة رسم/كتابة يدوية. تعيد مسار صورة PNG المحفوظة عند الحفظ.
class DrawingScreen extends StatefulWidget {
  final String? existingPath;
  const DrawingScreen({super.key, this.existingPath});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  late SignatureController _controller;
  Color _penColor = Colors.black;
  double _penWidth = 3;

  static const _palette = [
    Colors.black,
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF6D4C41),
  ];

  @override
  void initState() {
    super.initState();
    _controller = _makeController();
  }

  SignatureController _makeController({List<Point>? points}) => SignatureController(
        penStrokeWidth: _penWidth,
        penColor: _penColor,
        exportBackgroundColor: Colors.white,
        points: points,
      );

  void _applyPen() {
    // إنشاء متحكم جديد بالإعدادات الجديدة مع الحفاظ على النقاط الحالية.
    final points = List<Point>.from(_controller.points);
    final old = _controller;
    setState(() => _controller = _makeController(points: points));
    old.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final bytes = await _controller.toPngBytes(height: 1000, width: 1000);
    if (bytes == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final path = await FileService.instance.newAttachmentPath('png');
    await File(path).writeAsBytes(bytes, flush: true);
    if (mounted) Navigator.pop(context, path);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('drawing')),
        actions: [
          IconButton(
            tooltip: s.t('undo'),
            icon: const Icon(Icons.undo),
            onPressed: () => setState(_controller.undo),
          ),
          IconButton(
            tooltip: s.t('clear'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(_controller.clear),
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
            child: Container(
              color: Colors.white,
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.line_weight),
                      Expanded(
                        child: Slider(
                          min: 1,
                          max: 16,
                          value: _penWidth,
                          onChanged: (v) {
                            setState(() => _penWidth = v);
                          },
                          onChangeEnd: (_) => _applyPen(),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    children: _palette.map((c) {
                      final selected = c.value == _penColor.value;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _penColor = c);
                          _applyPen();
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black26,
                              width: selected ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
