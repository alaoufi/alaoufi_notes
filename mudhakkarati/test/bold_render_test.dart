import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mudhakkarati/features/editor/rich_text_field.dart';
import 'package:mudhakkarati/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';

/// حارس انحدار للغامق: يضمن أنّ الغامق (أ) يُعرض فعلًا، (ب) يُطبَّق من زرّ الشريط
/// في كل الحالات، (ج) لا يُفقد التحديد عند لمس الشريط (TextFieldTapRegion).
/// (هذه السيناريوهات أُثبِتت يدويًّا ثم ثُبِّتت هنا لمنع رجوع الخلل.)

Widget _wrap(Widget child) => ChangeNotifierProvider<SettingsProvider>(
      create: (_) => SettingsProvider(),
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );

bool _hasBold(QuillController q) =>
    jsonEncode(q.document.toDelta().toJson()).contains('"bold":true');

bool _rendersBold(WidgetTester tester) {
  for (final el in find.byType(RichText).evaluate()) {
    final rt = el.widget as RichText;
    var found = false;
    rt.text.visitChildren((span) {
      if (span is TextSpan &&
          (span.text?.isNotEmpty ?? false) &&
          (span.style?.fontWeight == FontWeight.bold ||
              span.style?.fontWeight == FontWeight.w700)) {
        found = true;
      }
      return true;
    });
    if (found) return true;
  }
  return false;
}

Future<void> _pump(WidgetTester tester, RichTextController c) async {
  await tester.pumpWidget(_wrap(Column(children: [
    Expanded(child: RichTextEditorBody(controller: c)),
    RichTextToolbar(controller: c),
  ])));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('١) الغامق المخزَّن يُعرض بوزن غامق', (tester) async {
    final delta = jsonEncode([
      {'insert': 'غامق', 'attributes': {'bold': true}},
      {'insert': ' عادي\n'},
    ]);
    final c = RichTextController(delta, (_) {});
    await tester.pumpWidget(_wrap(RichTextEditorBody(controller: c)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_rendersBold(tester), isTrue);
    c.dispose();
  });

  testWidgets('٢) زرّ الغامق + تحديد كلمة ⇒ غامق ويُعرض', (tester) async {
    final c = RichTextController('', (_) {});
    c.quill.replaceText(
        0, 0, 'سلام عليكم', const TextSelection.collapsed(offset: 10));
    await _pump(tester, c);
    c.quill.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 4), ChangeSource.local);
    await tester.pump();
    await tester.tap(find.byTooltip('غامق'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_hasBold(c.quill), isTrue);
    expect(_rendersBold(tester), isTrue);
    c.dispose();
  });

  testWidgets('٣) زرّ الغامق + مؤشّر داخل كلمة (بلا تحديد) ⇒ تُغمَّق الكلمة',
      (tester) async {
    final c = RichTextController('', (_) {});
    c.quill.replaceText(
        0, 0, 'سلام عليكم', const TextSelection.collapsed(offset: 2));
    await _pump(tester, c);
    c.quill.updateSelection(
        const TextSelection.collapsed(offset: 2), ChangeSource.local);
    await tester.pump();
    await tester.tap(find.byTooltip('غامق'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_hasBold(c.quill), isTrue);
    c.dispose();
  });

  testWidgets('٤) زرّ الغامق على محرّر فارغ ثم الكتابة ⇒ النص غامق',
      (tester) async {
    final c = RichTextController('', (_) {});
    await _pump(tester, c);
    c.quill.updateSelection(
        const TextSelection.collapsed(offset: 0), ChangeSource.local);
    await tester.pump();
    await tester.tap(find.byTooltip('غامق'));
    await tester.pump(const Duration(milliseconds: 50));
    c.quill.replaceText(0, 0, 'نص', const TextSelection.collapsed(offset: 2));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_hasBold(c.quill), isTrue);
    c.dispose();
  });

  testWidgets('٥) التحديد يبقى بعد لمس الشريط (لا يُفقد المحرّر تحديده)',
      (tester) async {
    final c = RichTextController('', (_) {});
    c.quill.replaceText(
        0, 0, 'سلام عليكم', const TextSelection.collapsed(offset: 10));
    await _pump(tester, c);
    await tester.tap(find.byType(RichTextEditorBody));
    await tester.pump(const Duration(milliseconds: 50));
    c.quill.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 4), ChangeSource.local);
    await tester.pump();
    final before = c.quill.selection;
    await tester.tap(find.byTooltip('غامق'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.quill.selection, before,
        reason: 'يبقى التحديد بعد لمس زرّ التنسيق');
    c.dispose();
  });
}
