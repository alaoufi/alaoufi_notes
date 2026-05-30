import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/category_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../data/models/category.dart';
import '../../services/security_service.dart';
import '../home/notes_provider.dart';
import '../security/pin_setup.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  static const _palette = [
    0xFF42A5F5, 0xFF7E57C2, 0xFFEF5350, 0xFF26A69A,
    0xFFFFA726, 0xFF66BB6A, 0xFFEC407A, 0xFF8D6E63,
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.watch<NotesProvider>();
    final cats = provider.categories;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('categories'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: cats.length,
        onReorder: (oldIndex, newIndex) {
          final list = List<Category>.from(cats);
          if (newIndex > oldIndex) newIndex -= 1;
          final item = list.removeAt(oldIndex);
          list.insert(newIndex, item);
          provider.reorderCategories(list);
        },
        itemBuilder: (context, i) {
          final c = cats[i];
          return ListTile(
            key: ValueKey(c.id),
            leading: CircleAvatar(
              backgroundColor: Color(c.color),
              child: Icon(categoryIconByIndex(c.iconCode),
                  color: Colors.white, size: 20),
            ),
            title: Text(c.name),
            subtitle: FutureBuilder<int>(
              future: provider.countByCategory(c.id!),
              builder: (context, snap) => Text(
                  '${snap.data ?? 0} ${s.t('notes_count')}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LockCategoryButton(categoryId: c.id!),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => provider.deleteCategory(c.id!),
                ),
                const Icon(Icons.drag_handle),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, Category? existing) async {
    final s = S.of(context);
    final provider = context.read<NotesProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int color = existing?.color ?? _palette.first;
    int icon = existing?.iconCode ?? 0; // فهرس في kCategoryIcons

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
                runSpacing: 8,
                children: List.generate(kCategoryIcons.length, (idx) {
                  final selected = icon == idx;
                  return GestureDetector(
                    onTap: () => setSheet(() => icon = idx),
                    child: CircleAvatar(
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(kCategoryIcons[idx], size: 20),
                    ),
                  );
                }),
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

/// زر قفل/فتح تصنيف. التصنيف المقفل تتطلب ملاحظاته رقمًا سريًا لعرضها.
class _LockCategoryButton extends StatefulWidget {
  final int categoryId;
  const _LockCategoryButton({required this.categoryId});

  @override
  State<_LockCategoryButton> createState() => _LockCategoryButtonState();
}

class _LockCategoryButtonState extends State<_LockCategoryButton> {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    SecurityService.instance
        .isCategoryLocked(widget.categoryId)
        .then((v) => mounted ? setState(() => _locked = v) : null);
  }

  Future<void> _toggle() async {
    if (!_locked) {
      // قفل التصنيف يتطلب وجود رقم سري للتطبيق.
      final ok = await ensurePinConfigured(context);
      if (!ok) return;
    }
    await SecurityService.instance
        .setCategoryLocked(widget.categoryId, !_locked);
    if (mounted) setState(() => _locked = !_locked);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _locked ? 'إلغاء قفل التصنيف' : 'قفل التصنيف',
      icon: Icon(_locked ? Icons.lock : Icons.lock_open_outlined,
          color: _locked ? Theme.of(context).colorScheme.primary : null),
      onPressed: _toggle,
    );
  }
}
