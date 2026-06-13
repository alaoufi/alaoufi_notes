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
  bool _unavailable = false;
  bool _listening = false;
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    bool ok = false;
    try {
      ok = await _stt.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _initDone = true;
      _unavailable = !ok;
    });
    if (ok) _listen();
  }

  Future<void> _listen() async {
    final lang = S.of(context).locale.languageCode;
    String? localeId;
    try {
      final locales = await _stt.locales();
      final match = locales
          .where((l) => l.localeId.toLowerCase().startsWith(lang))
          .toList();
      if (match.isNotEmpty) localeId = match.first.localeId;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _listening = true);
    await _stt.listen(
      onResult: (r) {
        if (mounted) setState(() => _text = r.recognizedWords);
      },
      localeId: localeId,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 4),
    );
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
    } else {
      _listen();
    }
  }

  @override
  void dispose() {
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.t('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _text.trim().isEmpty
                      ? null
                      : () async {
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
