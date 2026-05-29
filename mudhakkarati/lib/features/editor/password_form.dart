import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/password_entry.dart';

/// نموذج إدخال ملاحظة كلمات المرور: حقول منظمة + زر نسخ لكل حقل.
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
  late final TextEditingController _site;
  late final TextEditingController _app;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _notes;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _site = TextEditingController(text: widget.initial.site);
    _app = TextEditingController(text: widget.initial.app);
    _username = TextEditingController(text: widget.initial.username);
    _password = TextEditingController(text: widget.initial.password);
    _notes = TextEditingController(text: widget.initial.notes);
  }

  @override
  void dispose() {
    _site.dispose();
    _app.dispose();
    _username.dispose();
    _password.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(PasswordEntry(
      site: _site.text,
      app: _app.text,
      username: _username.text,
      password: _password.text,
      notes: _notes.text,
    ));
  }

  Future<void> _copy(String value) async {
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).t('pw_copied'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(s.t('pw_site'), _site, Icons.language),
        _field(s.t('pw_app'), _app, Icons.apps),
        _field(s.t('pw_username'), _username, Icons.person_outline),
        _passwordField(s),
        _field(s.t('pw_notes'), _notes, Icons.notes, maxLines: 3),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.lock, size: 14, color: Theme.of(context).hintColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s.t('pw_encrypted_hint'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        onChanged: (_) => _emit(),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: IconButton(
            tooltip: S.of(context).t('copy'),
            icon: const Icon(Icons.copy),
            onPressed: () => _copy(ctrl.text),
          ),
        ),
      ),
    );
  }

  Widget _passwordField(S s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _password,
        obscureText: _obscure,
        onChanged: (_) => _emit(),
        decoration: InputDecoration(
          labelText: s.t('pw_password'),
          prefixIcon: const Icon(Icons.vpn_key),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _obscure ? s.t('pw_show') : s.t('pw_hide'),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              IconButton(
                tooltip: s.t('copy'),
                icon: const Icon(Icons.copy),
                onPressed: () => _copy(_password.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
