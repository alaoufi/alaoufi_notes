import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/category.dart';
import '../home/notes_provider.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  static const _palette = [
    0xFF42A5F5, 0xFF7E57C2, 0xFFEF5350, 0xFF26A69A,
    0xFFFFA726, 0xFF66BB6A, 0xFFEC407A, 0xFF8D6E63,
  ];

  static const _icons = [
    0xe7fd, 0xe8f9, 0xe838, 0xe935, 0xe90f, 0xe0c9, 0xe55b, 0xe87d,
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.watch<NotesProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(s.t('categories'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: provider.categories.map((c) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(c.color),
              child: Icon(IconData(c.iconCode, fontFamily: 'MaterialIcons'),
                  color: Colors.white, size: 20),
            ),
            title: Text(c.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => provider.deleteCategory(c.id!),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Category? existing) async {
    final s = S.of(context);
    final provider = context.read<NotesProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int color = existing?.color ?? _palette.first;
    int icon = existing?.iconCode ?? _icons.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? s.t('add_category') : s.t('edit_category'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: s.t('category_name')),
              ),
              const SizedBox(height: 16),
              Text(s.t('color')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _palette.map((c) {
                  return GestureDetector(
                    onTap: () => setSheet(() => color = c),
                    child: CircleAvatar(
                      backgroundColor: Color(c),
                      child: color == c
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _icons.map((ic) {
                  final selected = icon == ic;
                  return GestureDetector(
                    onTap: () => setSheet(() => icon = ic),
                    child: CircleAvatar(
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                          IconData(ic, fontFamily: 'MaterialIcons'),
                          size: 20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    if (existing == null) {
                      await provider.addCategory(Category(
                          name: name,
                          color: color,
                          iconCode: icon,
                          position: provider.categories.length));
                    } else {
                      await provider.updateCategory(existing.copyWith(
                          name: name, color: color, iconCode: icon));
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(s.t('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
