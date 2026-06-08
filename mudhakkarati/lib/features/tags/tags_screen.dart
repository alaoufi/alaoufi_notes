import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../home/notes_provider.dart';

/// صفحة العلامات (الوسوم): اختيار وسم يفلتر القائمة الرئيسية.
class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  List<String> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tags = await context.read<NotesProvider>().allTags();
    if (mounted) setState(() { _tags = tags; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('tags_page'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? Center(child: Text(s.t('tags')))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map((t) => ActionChip(
                              avatar: const Icon(Icons.tag, size: 18),
                              label: Text(t),
                              onPressed: () {
                                context.read<NotesProvider>().setTagFilter(t);
                                Navigator.pop(context);
                              },
                            ))
                        .toList(),
                  ),
                ),
    );
  }
}
