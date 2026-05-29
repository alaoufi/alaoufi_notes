import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/note.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('trash')),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () async {
                await provider.emptyTrash();
                await _load();
              },
              child: Text(s.t('empty_trash')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text(s.t('trash')))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final n = _items[i];
                    return ListTile(
                      leading: const Icon(Icons.note_outlined),
                      title: Text(
                        n.title.isNotEmpty ? n.title : n.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                            icon: const Icon(Icons.delete_forever),
                            onPressed: () async {
                              await provider.deleteForever(n);
                              await _load();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
