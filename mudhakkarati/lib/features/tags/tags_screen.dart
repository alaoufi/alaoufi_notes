import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../widgets/ui_kit.dart';
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
      appBar: gradientAppBar(context, s.t('tags_page')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const EmptyState(
                  icon: Icons.tag,
                  title: 'لا توجد وسوم بعد',
                  subtitle: 'أضف وسومًا للملاحظات لتظهر هنا')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _tags.map((t) {
                      // لون مستقرّ لكل وسم مشتقّ من نصّه.
                      final hue = (t.hashCode % 360).abs().toDouble();
                      final c = HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();
                      return Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(24),
                        shadowColor: c.withOpacity(0.5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            context.read<NotesProvider>().setTagFilter(t);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(colors: [
                                c.withOpacity(0.85),
                                c.withOpacity(0.6),
                              ]),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag,
                                    size: 18, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(t,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}
