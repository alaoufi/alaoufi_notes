import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mudhakkarati/features/editor/rich_text_field.dart';
import 'package:mudhakkarati/features/settings/settings_provider.dart';
import 'package:provider/provider.dart';

/// اختبارات سلوك المحرّر بعد اعتماد **اتجاه يمين (RTL) ثابت** بلا «اتجاه كل سطر»:
///
/// هذه الاختبارات تغطّي الحالات التي أبلغ عنها المستخدم وتمنع رجوعها:
///  1) الملاحظة الجديدة تبدأ والمؤشّر عند البداية (يمينًا) — لا يسارًا.
///  2) الكتابة (عربي/إنجليزي/مختلط/أسطر جديدة) **لا تضيف** سمة اتجاه لأي سطر
///     ⇒ لا قفز يمين↔يسار، ولا تعارض مع الغامق/المائل.
///  3) الحفظ يُنظّف أي سمة اتجاه قديمة (ملاحظات سابقة) فلا تتراكم.
///  4) المحرّر والعارض كلاهما بمحيط RTL ثابت.
///  5) الحذف لا يحرّك المؤشّر (المحرّر لا يلمس التحديد إطلاقًا).

/// يستخرج كل قيم سمة 'direction' الموجودة في Delta JSON (يجب أن تكون فارغة).
List<dynamic> _directionsIn(QuillController q) {
  final ops = q.document.toDelta().toJson();
  final dirs = <dynamic>[];
  for (final op in ops) {
    if (op['attributes'] is Map) {
      final d = (op['attributes'] as Map)['direction'];
      if (d != null) dirs.add(d);
    }
  }
  return dirs;
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<SettingsProvider>(
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
}

/// اتجاه أقرب Directionality فوق محرّر Quill في الشجرة.
TextDirection _ambientDirOf(WidgetTester tester) {
  final dir = tester.widget<Directionality>(
    find
        .ancestor(
          of: find.byType(QuillEditor),
          matching: find.byType(Directionality),
        )
        .first,
  );
  return dir.textDirection;
}

void main() {
  group('RichTextController — بلا اتجاه لكل سطر (مستقرّ)', () {
    test('١) ملاحظة جديدة: المؤشّر عند البداية (offset 0)', () {
      final c = RichTextController('', (_) {});
      expect(c.quill.selection.baseOffset, 0);
      expect(c.quill.selection.isCollapsed, true);
      c.dispose();
    });

    test('٢) كتابة عربي/إنجليزي/مختلط + أسطر جديدة: لا تُضاف أي سمة اتجاه', () {
      final c = RichTextController('', (_) {});
      // عربي ثم سطر جديد ثم إنجليزي ثم سطر مختلط.
      c.quill.document.insert(0, 'مرحبا بالعالم');
      c.quill.document.insert(c.quill.document.length - 1, '\nHello world');
      c.quill.document
          .insert(c.quill.document.length - 1, '\nعربي with English 123');
      expect(_directionsIn(c.quill), isEmpty,
          reason: 'يجب ألّا يضيف المحرّر أي سمة direction (لا قفز اتجاه)');
      c.dispose();
    });

    test('٣) فتح ملاحظة قديمة فيها سمة اتجاه: الحفظ يُنظّفها', () async {
      // مستند قديم: سطر معلّم rtl صراحةً (كما كانت تخزّنه نسخ سابقة).
      final legacy = jsonEncode([
        {'insert': 'سطر قديم'},
        {
          'insert': '\n',
          'attributes': {'direction': 'rtl', 'align': 'right'}
        },
        {'insert': 'تالٍ'},
        {'insert': '\n'},
      ]);

      String? saved;
      final c = RichTextController(legacy, (json) => saved = json);

      // يُحمّل المستند دون أخطاء، والسمة موجودة فيه ابتداءً.
      expect(_directionsIn(c.quill), contains('rtl'));

      // عدّل النص عبر واجهة المتحكّم (كالكتابة الحقيقية) لتشغيل الحفظ المؤجّل.
      c.quill.replaceText(0, 0, 'ا', const TextSelection.collapsed(offset: 1));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(saved, isNotNull, reason: 'يجب أن يُستدعى onChanged بعد التأجيل');
      expect(saved, isNot(contains('"direction"')),
          reason: 'الحفظ يجب أن يُزيل أي سمة اتجاه قديمة');
      // و«align» يبقى (لا نمسّ إلا الاتجاه).
      expect(saved, contains('align'));
      c.dispose();
    });

    test('٤) الحفظ يُنتج Delta JSON صالحًا يُعاد تحميله بنفس النص', () async {
      String? saved;
      final c = RichTextController('', (json) => saved = json);
      const text = 'نص للاختبار\nسطر ثانٍ';
      c.quill.replaceText(
          0, 0, text, TextSelection.collapsed(offset: text.length));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(saved, isNotNull);
      final reloaded = Document.fromJson(jsonDecode(saved!) as List);
      expect(reloaded.toPlainText().trim(), 'نص للاختبار\nسطر ثانٍ');
      c.dispose();
    });

    test('٥) لمس/تحريك المؤشّر فقط (دون تغيّر نصّ) لا يستدعي الحفظ', () async {
      var calls = 0;
      final c = RichTextController('نص', (_) => calls++);
      // تغيير التحديد فقط (محاكاة لمسة) — لا يغيّر النص.
      c.quill.updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(calls, 0, reason: 'اللمس لا يجب أن يحفظ (استقرار)');
      c.dispose();
    });

    test('٨) الغامق يبقى محفوظًا عبر الحفظ (يُزال الاتجاه فقط)', () async {
      String? saved;
      final c = RichTextController('', (json) => saved = json);
      const text = 'غامق عادي';
      c.quill.replaceText(
          0, 0, text, TextSelection.collapsed(offset: text.length));
      c.quill.formatText(0, 4, Attribute.bold); // الكلمة الأولى غامقة
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(saved, isNotNull);
      expect(saved, contains('bold'), reason: 'الغامق يجب أن يبقى');
      expect(saved, isNot(contains('"direction"')));
      c.dispose();
    });
  });

  group('اتجاه المحيط RTL ثابت (واجهة)', () {
    testWidgets('٦) محرّر التحرير بمحيط RTL', (tester) async {
      final c = RichTextController('', (_) {});
      await tester.pumpWidget(_wrap(RichTextEditorBody(controller: c)));
      await tester.pump();
      expect(_ambientDirOf(tester), TextDirection.rtl);
      c.dispose();
    });

    testWidgets('٧) العارض (القراءة) بمحيط RTL', (tester) async {
      await tester.pumpWidget(_wrap(const RichTextViewer(content: 'مرحبا')));
      await tester.pump();
      expect(_ambientDirOf(tester), TextDirection.rtl);
    });
  });
}
