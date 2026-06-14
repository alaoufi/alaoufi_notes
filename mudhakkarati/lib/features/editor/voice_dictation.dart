import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/text/line_direction.dart';

/// يفتح ورقة الإملاء الصوتيّ ويعيد النصّ المتعرَّف عليه (أو null عند الإلغاء).
///
/// دورة كاملة موثوقة: إذن الميكروفون → تهيئة المحرّك → استماع → نتائج جزئية
/// مباشرة → إرجاع النصّ لإدراجه في موضع المؤشر. تتضمّن منع `error_busy`،
/// وتنظيف الموارد، ومعالجة كل حالات الفشل، ووضع اختبار يعرض سجلّ المراحل.
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

enum _Phase { starting, permDenied, unavailable, ready, error }

class _DictationSheetState extends State<_DictationSheet> {
  final SpeechToText _stt = SpeechToText();
  String _text = ''; // النتيجة الجزئية للجلسة الحالية
  String _committed = ''; // ما تأكّد من الجلسات السابقة (تجميع)
  String get _display => [_committed, _text]
      .where((p) => p.trim().isNotEmpty)
      .join(' ')
      .trim();
  String _status = 'idle';
  String? _err; // مفتاح/رسالة خطأ
  _Phase _phase = _Phase.starting;
  bool _listening = false;
  bool _want = false; // المستخدم يريد الاستماع
  bool _busyGuard = false; // يمنع بدء جلسة أثناء عملية بدء/إلغاء أخرى
  bool _restarting = false; // يسلسل إعادة التشغيل التلقائيّ
  int _busyTries = 0;
  bool _onDevice = false; // يتناوب: إنترنت ↔ على الجهاز (أيّهما يعمل يلتقط)
  bool _localeMissing = false; // لا توجد لغة التطبيق ضمن لغات المحرّك
  String? _localeId;
  bool _debug = false;
  final List<String> _log = [];

  void _logE(String e) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    _log.add('$t  $e');
    if (_log.length > 60) _log.removeAt(0);
    // ignore: avoid_print
    print('[STT] $e');
    // لا نستدعي setState هنا (قد يُستدعى داخل initState قبل أول بناء)؛
    // تحديثات الحالة الأخرى (status/result/error) تُنعش لوحة الاختبار.
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  // ===================== دورة الإملاء =====================
  Future<void> _start() async {
    _logE('START dictation');

    // 1) إذن الميكروفون (صريح للتشخيص).
    var perm = await Permission.microphone.status;
    _logE('mic permission = $perm');
    if (!perm.isGranted) {
      perm = await Permission.microphone.request();
      _logE('mic permission after request = $perm');
    }
    if (!perm.isGranted) {
      _logE('PERMISSION DENIED → stop');
      if (mounted) {
        setState(() {
          _phase = _Phase.permDenied;
          _err = 'stt_perm_denied';
        });
      }
      return;
    }

    // 2) تهيئة المحرّك (تُسجّل ردود هذه الورقة في كل مرّة).
    bool ok = false;
    try {
      ok = await _stt.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: true,
      );
      _logE('initialize() = $ok');
    } catch (e) {
      ok = false;
      _logE('initialize EXCEPTION: $e');
    }

    if (!ok) {
      if (mounted) {
        setState(() {
          _phase = _Phase.unavailable;
          _err = 'stt_unavailable';
        });
      }
      return;
    }

    // 3) اختيار لغة التعرّف — مع طباعة كل اللغات المتاحة للتشخيص، واختيار
    //    العربية بمرونة (ar_SA → أيّ ar_* → ar → لغة النظام).
    try {
      final lang = S.of(context).locale.languageCode;
      final locales = await _stt.locales();
      final ids = locales.map((l) => l.localeId).toList();
      _logE('locales(${ids.length}): ${ids.take(40).join(", ")}');

      String norm(String s) => s.toLowerCase().replaceAll('-', '_');
      final wanted = locales
          .where((l) => norm(l.localeId) == lang || norm(l.localeId).startsWith('${lang}_'))
          .toList();
      if (wanted.isNotEmpty) {
        // فضّل الصيغة الإقليمية (مثل ar_SA) إن وُجدت.
        final region = wanted.firstWhere(
          (l) => norm(l.localeId) == '${lang}_sa' || norm(l.localeId).contains('_'),
          orElse: () => wanted.first,
        );
        _localeId = region.localeId;
        _logE('selected $lang locale: $_localeId');
      } else {
        _localeMissing = true;
        _localeId = (await _stt.systemLocale())?.localeId;
        _logE('NO "$lang" locale on device! using system: $_localeId');
      }
    } catch (e) {
      _logE('locale detect EXCEPTION: $e');
    }

    if (!mounted) return;
    setState(() => _phase = _Phase.ready);
    _want = true;
    // تنظيف أي جلسة عالقة من تشغيل سابق ثم بدء نظيف.
    await _hardReset();
    _startListen();
  }

  /// يضمن تحرير المحرّك تمامًا قبل جلسة جديدة (مفتاح منع error_busy).
  Future<void> _hardReset() async {
    try {
      if (_stt.isListening) {
        await _stt.stop();
        _logE('hardReset: stopped active session');
      }
      await _stt.cancel();
      _logE('hardReset: cancelled');
    } catch (e) {
      _logE('hardReset EXCEPTION: $e');
    }
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _startListen() async {
    if (!_want) return;
    if (_busyGuard) {
      _logE('startListen skipped (busy guard)');
      return;
    }
    if (_stt.isListening) {
      _logE('startListen skipped (already listening)');
      return;
    }
    _busyGuard = true;
    try {
      _logE('listen() starting… locale=$_localeId onDevice=$_onDevice');
      await _stt.listen(
        onResult: _onResult,
        localeId: _localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          onDevice: _onDevice,
        ),
      );
      _logE('listen() returned. isListening=${_stt.isListening}');
    } catch (e) {
      _logE('listen() EXCEPTION: $e');
      if (mounted) setState(() => _err = '$e');
    } finally {
      _busyGuard = false;
    }
  }

  // ===================== ردود المحرّك =====================
  void _onStatus(String s) {
    _status = s;
    final listening = _stt.isListening;
    if (listening) _busyTries = 0;
    _logE('status = $s (isListening=$listening)');
    if (mounted) setState(() => _listening = listening);
    // استماع متواصل: إن انتهت الجلسة والمستخدم ما زال يريد ⇒ أعد تشغيلًا نظيفًا.
    if (!listening && _want && !_busyGuard) _autoRestart();
  }

  /// إعادة تشغيل آمنة (تحرير كامل أولًا) كي يبقى المايك نشطًا دون error_busy.
  Future<void> _autoRestart() async {
    if (_restarting || _busyGuard || !_want || _stt.isListening) return;
    _restarting = true;
    await _hardReset();
    _restarting = false;
    // بدّل وضع التعرّف (إنترنت ↔ على الجهاز) كي يلتقط الكلامَ أيّهما يعمل.
    _onDevice = !_onDevice;
    if (mounted && _want && !_stt.isListening) {
      _logE('auto-restart (onDevice=$_onDevice)');
      _startListen();
    }
  }

  void _onResult(dynamic r) {
    final words = r.recognizedWords as String? ?? '';
    final isFinal = (r.finalResult as bool?) ?? false;
    double conf = 0;
    try {
      conf = (r.confidence as num?)?.toDouble() ?? 0;
    } catch (_) {}
    _logE('RESULT "$words" final=$isFinal conf=${conf.toStringAsFixed(2)}');
    if (words.trim().isNotEmpty) _err = null; // وصل نصّ ⇒ أزل أي رسالة
    if (!mounted) return;
    setState(() {
      if (isFinal) {
        // ثبّت النتيجة النهائية في المخزَّن كي لا تضيع عند إعادة التشغيل.
        if (words.trim().isNotEmpty) {
          _committed =
              _committed.isEmpty ? words.trim() : '$_committed ${words.trim()}';
        }
        _text = '';
      } else {
        _text = words;
      }
    });
  }

  void _onError(dynamic e) {
    final msg = (e.errorMsg as String?) ?? '$e';
    final permanent = (e.permanent as bool?) ?? false;
    _logE('ERROR $msg (permanent=$permanent)');
    if (!mounted) return;
    // الانشغال شائع في MIUI ⇒ إعادة محاولة متدرّجة بعد تحرير المحرّك.
    if (msg.contains('busy') || msg.contains('client')) {
      _scheduleBusyRetry();
      return;
    }
    // صمت/عدم تطابق ⇒ ليس خطأً قاطعًا؛ نُبقي الاستماع المتواصل ونُظهر تنبيهًا
    // واضحًا فقط إن لم يصل أي نصّ بعد (والمستخدم يرى أنه يحاول).
    if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      if (_display.isEmpty) {
        setState(() => _err = _localeMissing ? 'stt_busy_help' : 'stt_no_speech');
      }
      return;
    }
    setState(() => _err = msg);
  }

  void _scheduleBusyRetry() {
    if (!_want || _busyGuard) return;
    if (_busyTries >= 5) {
      _logE('busy retries exhausted → show help');
      if (mounted) setState(() => _err = 'busy_help');
      return;
    }
    _busyTries++;
    final delay = 500 * _busyTries;
    _logE('busy → retry #$_busyTries after ${delay}ms');
    _busyGuard = true;
    Future.delayed(Duration(milliseconds: delay), () async {
      await _hardReset();
      _busyGuard = false;
      if (mounted && _want && !_stt.isListening) _startListen();
    });
  }

  // ===================== أزرار =====================
  Future<void> _toggle() async {
    if (_stt.isListening) {
      _want = false;
      await _stt.stop();
      _logE('user stopped');
      if (mounted) setState(() => _listening = false);
    } else {
      _want = true;
      _busyTries = 0;
      if (mounted) setState(() => _err = null);
      await _hardReset();
      _startListen();
    }
  }

  void _insert() async {
    _want = false;
    await _stt.stop();
    final out = _display;
    _logE('INSERT "$out"');
    if (mounted) Navigator.pop(context, out);
  }

  @override
  void dispose() {
    _want = false;
    // تنظيف الموارد عند الإغلاق.
    _stt.stop();
    _stt.cancel();
    super.dispose();
  }

  // ===================== الواجهة =====================
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;

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
                const Spacer(),
                // زرّ وضع الاختبار (يعرض السجلّ التفصيليّ).
                IconButton(
                  tooltip: 'Debug',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.bug_report_outlined,
                      size: 20,
                      color: _debug ? scheme.primary : scheme.outline),
                  onPressed: () => setState(() => _debug = !_debug),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _body(s, scheme),
            if (_debug) _debugPanel(scheme),
          ],
        ),
      ),
    );
  }

  Widget _body(S s, ColorScheme scheme) {
    if (_phase == _Phase.starting) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_phase == _Phase.permDenied) {
      return Column(
        children: [
          Icon(Icons.mic_off, color: scheme.error, size: 40),
          const SizedBox(height: 10),
          Text(s.t('stt_perm_denied'), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => openAppSettings(),
            icon: const Icon(Icons.settings),
            label: Text(s.t('stt_open_settings')),
          ),
        ],
      );
    }
    if (_phase == _Phase.unavailable) {
      return Column(
        children: [
          Icon(Icons.mic_off, color: scheme.error, size: 40),
          const SizedBox(height: 10),
          Text(s.t('stt_unavailable'), textAlign: TextAlign.center),
        ],
      );
    }

    // جاهز.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            style:
                TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60, maxHeight: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: SingleChildScrollView(
            reverse: true,
            child: Text(
              _display.isEmpty ? '…' : _display,
              textDirection: lineDirection(_display),
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        ),
        if (_err != null && _display.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
              _err == 'busy_help'
                  ? '⚠ ${s.t('stt_busy_help')}'
                  : (s.t(_err!) == _err! ? '⚠ $_err' : '⚠ ${s.t(_err!)}'),
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
                onPressed: _display.trim().isEmpty ? null : _insert,
                icon: const Icon(Icons.check),
                label: Text(s.t('stt_insert')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _debugPanel(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'state=$_status  listening=$_listening  locale=$_localeId  '
            'tries=$_busyTries',
            style: const TextStyle(
                color: Colors.greenAccent, fontSize: 10.5, height: 1.4),
          ),
          const Divider(color: Colors.white24, height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _log.join('\n'),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.35,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
