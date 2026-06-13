import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/text/line_direction.dart';

/// يفتح ورقة الإملاء الصوتيّ ويعيد النصّ المتعرَّف عليه (أو null عند الإلغاء).
///
/// يستخدم محرّك التعرّف الصوتيّ المدمج في النظام (Google) — يعمل بدون إنترنت على
/// أغلب الأجهزة بعد تنزيل حزمة اللغة، ولا يرفع أي بيانات لخادم خاصّ بنا.
Future<String?> showVoiceDictation(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _DictationSheet(),
  );
}

class _DictationSheet extends StatefulWidget {
  const _DictationSheet();

  @override
  State<_DictationSheet> createState() => _DictationSheetState();
}

class _DictationSheetState extends State<_DictationSheet> {
  final SpeechToText _stt = SpeechToText();
  String _text = '';
  String? _err; // رسالة خطأ للتشخيص (تظهر للمستخدم)
  bool _unavailable = false;
  bool _listening = false;
  bool _initDone = false;
  bool _want = false; // المستخدم يريد الاستماع (لإعادة التشغيل المتواصل)
  String? _localeId;

  @override
  void initState() {
    super.initState();
    _start();
  }

  bool _retrying = false; // لتسلسل إعادة المحاولة (تفادي error_busy)

  Future<void> _start() async {
    bool ok = false;
    try {
      ok = await _stt.initialize(onStatus: _onStatus, onError: _onError);
    } catch (e) {
      ok = false;
      _err = '$e';
    }
    if (!mounted) return;
    // حدّد لغة التعرّف حسب لغة التطبيق (مرّة واحدة).
    try {
      final lang = S.of(context).locale.languageCode;
      final locales = await _stt.locales();
      final match =
          locales.where((l) => l.localeId.toLowerCase().startsWith(lang));
      if (match.isNotEmpty) _localeId = match.first.localeId;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _initDone = true;
      _unavailable = !ok;
    });
    if (ok) {
      _want = true;
      // مهلة قصيرة قبل أول استماع كي يتحرّر المتعرّف بعد التهيئة (يمنع البدء المشغول).
      await Future.delayed(const Duration(milliseconds: 350));
      _listen();
    }
  }

  void _onStatus(String s) {
    if (!mounted) return;
    setState(() => _listening = _stt.isListening);
  }

  void _onError(dynamic e) {
    if (!mounted) return;
    final msg = e.errorMsg as String? ?? '$e';
    setState(() => _err = msg);
    // المتعرّف مشغول/خطأ مؤقّت ⇒ تنظيف ثم محاولة واحدة بعد تهدئة.
    if (msg == 'error_busy' || msg == 'error_client') {
      _cleanRetry();
    }
  }

  /// يُلغي أي جلسة عالقة، ينتظر قليلًا، ثم يبدأ استماعًا نظيفًا (يعالج error_busy).
  Future<void> _cleanRetry() async {
    if (_retrying || !_want) return;
    _retrying = true;
    try {
      await _stt.cancel();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 800));
    _retrying = false;
    if (mounted && _want && !_stt.isListening) _listen();
  }

  Future<void> _listen() async {
    if (_stt.isListening || _retrying) return;
    if (mounted) setState(() => _err = null);
    try {
      await _stt.listen(
        onResult: (r) {
          if (mounted) setState(() => _text = r.recognizedWords);
        },
        localeId: _localeId,
        // جلسة طويلة بمهلة صمت كبيرة كي لا تتوقّف بسرعة (بلا حلقة إعادة تشغيل).
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
      );
      if (mounted) setState(() => _listening = _stt.isListening);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _toggle() async {
    if (_stt.isListening) {
      _want = false;
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
    } else {
      _want = true;
      await _cleanRetry();
    }
  }

  @override
  void dispose() {
    _want = false;
    _stt.stop();
    _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (_unavailable) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.mic_off, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(s.t('stt_unavailable'))),
          ],
        ),
      );
    } else if (!_initDone) {
      body = const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // زرّ المايك النابض.
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _listening
                      ? [scheme.primary, scheme.tertiary]
                      : [scheme.surfaceContainerHighest, scheme.outline],
                ),
                boxShadow: _listening
                    ? [
                        BoxShadow(
                            color: scheme.primary.withOpacity(0.5),
                            blurRadius: 24,
                            spreadRadius: 2)
                      ]
                    : null,
              ),
              child: Icon(_listening ? Icons.mic : Icons.mic_none,
                  size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(_listening ? s.t('stt_listening') : s.t('stt_speak_now'),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60, maxHeight: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _text.isEmpty ? '…' : _text,
                textDirection: lineDirection(_text),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          ),
          if (_err != null && _text.isEmpty) ...[
            const SizedBox(height: 8),
            Text('⚠ $_err',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: scheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _want = false;
                    Navigator.pop(context);
                  },
                  child: Text(s.t('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _text.trim().isEmpty
                      ? null
                      : () async {
                          _want = false;
                          await _stt.stop();
                          if (context.mounted) {
                            Navigator.pop(context, _text.trim());
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: Text(s.t('stt_insert')),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.keyboard_voice, color: scheme.primary),
                const SizedBox(width: 8),
                Text(s.t('voice_typing'),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );
  }
}
