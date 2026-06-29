import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/password_entry.dart';

/// نموذج إدخال ملاحظة كلمات المرور: حقول منظمة + نسخ لكل حقل + مولّد + مؤشّر قوة.
class PasswordForm extends StatefulWidget {
  final PasswordEntry initial;
  final ValueChanged<PasswordEntry> onChanged;

  const PasswordForm({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  late final TextEditingController _name;
  late final TextEditingController _link;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _notes;
  bool _obscure = true;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _link = TextEditingController(text: widget.initial.link);
    _username = TextEditingController(text: widget.initial.username);
    _password = TextEditingController(text: widget.initial.password);
    _notes = TextEditingController(text: widget.initial.notes);
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _name.dispose();
    _link.dispose();
    _username.dispose();
    _password.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(PasswordEntry(
      name: _name.text,
      link: _link.text,
      username: _username.text,
      password: _password.text,
      notes: _notes.text,
    ));
  }

  /// نسخ عادي.
  Future<void> _copy(String value) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    _toast(S.of(context).t('pw_copied'));
  }

  /// نسخ آمن: يُمسح من الحافظة تلقائيًا بعد 30 ثانية.
  Future<void> _copySecure(String value) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    _toast('${S.of(context).t('pw_copied')} — ${S.of(context).t('pw_clear_30')}');
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 30), () async {
      final data = await Clipboard.getData('text/plain');
      if (data?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _generate() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnpqrstuvwxyz';
    const digits = '23456789';
    const symbols = '!@#\$%&*?-_=+';
    const all = upper + lower + digits + symbols;
    final rnd = Random.secure();
    const len = 16;
    // نضمن وجود صنف واحد على الأقل من كل نوع.
    final chars = <String>[
      upper[rnd.nextInt(upper.length)],
      lower[rnd.nextInt(lower.length)],
      digits[rnd.nextInt(digits.length)],
      symbols[rnd.nextInt(symbols.length)],
    ];
    for (var i = chars.length; i < len; i++) {
      chars.add(all[rnd.nextInt(all.length)]);
    }
    chars.shuffle(rnd);
    setState(() {
      _password.text = chars.join();
      _obscure = false;
    });
    _emit();
  }

  // 0..4
  int _strength(String p) {
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score.clamp(0, 4);
  }

  // لون مميِّز لكل حقل (أيقونة + إطار التركيز) — لمسة بصريّة هادئة ومرتّبة.
  static const _cName = Color(0xFF5C6BC0); // الاسم
  static const _cLink = Color(0xFF42A5F5); // الرابط
  static const _cUser = Color(0xFF26A69A); // اسم المستخدم
  static const _cPass = Color(0xFFEF6C00); // كلمة المرور
  static const _cNote = Color(0xFF78909C); // ملاحظات

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(s.t('pw_name'), _name, Icons.badge_outlined, _cName),
        _field(s.t('pw_link'), _link, Icons.link, _cLink,
            keyboardType: TextInputType.url),
        _field(s.t('pw_username'), _username, Icons.person_outline, _cUser),
        _passwordField(s),
        _strengthBar(s),
        _field(s.t('pw_notes'), _notes, Icons.notes, _cNote, maxLines: 3),
        const SizedBox(height: 14),
        _hint(s),
      ],
    );
  }

  /// زخرفة موحّدة: حقل أبيض مستدير، أيقونة داخل مربّع لونيّ ناعم، إطار تركيز ملوّن.
  InputDecoration _decoration(String label, IconData icon, Color accent,
      {Widget? suffix}) {
    final divider = Theme.of(context).dividerColor;
    final fill = Theme.of(context).colorScheme.surface;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fill.withOpacity(0.94),
      prefixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 0),
      prefixIcon: Container(
        margin: const EdgeInsetsDirectional.only(start: 10, end: 6),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accent, size: 21),
      ),
      suffixIcon: suffix,
      border: border(Colors.transparent, 0),
      enabledBorder: border(divider.withOpacity(0.4), 1),
      focusedBorder: border(accent, 1.6),
    );
  }

  Widget _copyBtn(VoidCallback onTap) => IconButton(
        tooltip: S.of(context).t('copy'),
        icon: const Icon(Icons.copy_rounded, size: 20),
        onPressed: onTap,
      );

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      Color accent, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: (_) => _emit(),
        decoration: _decoration(label, icon, accent,
            suffix: _copyBtn(() => _copy(ctrl.text))),
      ),
    );
  }

  Widget _passwordField(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: _password,
        obscureText: _obscure,
        onChanged: (_) {
          setState(() {});
          _emit();
        },
        decoration: _decoration(s.t('pw_password'), Icons.vpn_key, _cPass,
          suffix: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: s.t('pw_generate'),
                icon: const Icon(Icons.casino_outlined, size: 20),
                onPressed: _generate,
              ),
              IconButton(
                tooltip: _obscure ? s.t('pw_show') : s.t('pw_hide'),
                icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              IconButton(
                tooltip: s.t('copy'),
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () => _copySecure(_password.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strengthBar(S s) {
    if (_password.text.isEmpty) return const SizedBox(height: 4);
    final score = _strength(_password.text);
    const labels = ['ضعيفة جدًا', 'ضعيفة', 'متوسطة', 'جيدة', 'قوية'];
    const colors = [
      Color(0xFFE53935),
      Color(0xFFFB8C00),
      Color(0xFFFDD835),
      Color(0xFF7CB342),
      Color(0xFF2E7D32),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 8, bottom: 4, top: 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (score + 1) / 5,
                minHeight: 7,
                backgroundColor: Theme.of(context).dividerColor.withOpacity(0.4),
                color: colors[score],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(labels[score],
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors[score])),
        ],
      ),
    );
  }

  Widget _hint(S s) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined,
              size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.t('pw_encrypted_hint'),
                style: TextStyle(
                    fontSize: 12.5, color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}
