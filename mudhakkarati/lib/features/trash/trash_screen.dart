import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/note.dart';
import '../../widgets/ui_kit.dart';
import '../home/notes_provider.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Note> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<NotesProvider>().getTrash();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final provider = context.read<NotesProvider>();

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: gradientAppBar(context, s.t('trash'), actions: [
        if (_items.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              await provider.emptyTrash();
              await _load();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(s.t('empty_trash')),
          ),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.delete_outline,
                  title: 'سلة المهملات فارغة',
                  subtitle: 'الملاحظات المحذوفة تظهر هنا ويمكنك استرجاعها')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final n = _items[i];
                    return AppCard(
                      child: ListTile(
                        leading:
                            GradientIcon(Icons.note_outlined, color: scheme.errorContainer),
                        title: Text(
                          n.title.isNotEmpty ? n.title : n.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: s.t('restore'),
                              icon: const Icon(Icons.restore),
                              onPressed: () async {
                                await provider.restore(n.id!);
                                await _load();
                              },
                            ),
                            IconButton(
                              tooltip: s.t('delete_forever'),
                              color: scheme.error,
                              icon: const Icon(Icons.delete_forever),
                              onPressed: () async {
                                await provider.deleteForever(n);
                                await _load();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
