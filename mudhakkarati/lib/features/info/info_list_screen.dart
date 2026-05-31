import 'package:flutter/material.dart';

import '../../data/models/info_entry.dart';
import '../../data/repositories/info_repository.dart';
import 'info_detail_screen.dart';
import 'info_edit_screen.dart';

/// صفحة «معلومات عامة» — قاعدة بيانات داخلية مع بحث وعرض احترافي.
class InfoListScreen extends StatefulWidget {
  const InfoListScreen({super.key});

  @override
  State<InfoListScreen> createState() => _InfoListScreenState();
}

class _InfoListScreenState extends State<InfoListScreen> {
  final _repo = InfoRepository();
  final _searchCtrl = TextEditingController();
  List<InfoEntry> _items = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items =
        _query.trim().isEmpty ? await _repo.getAll() : await _repo.search(_query);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const InfoEditScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _open(InfoEntry e) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => InfoDetailScreen(entry: e)),
    );
    // أعد التحميل دائمًا عند الرجوع (قد يكون عُدّل أو حُذف).
    _load();
  }

  String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('معلومات عامة'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _query = v;
                _load();
              },
              decoration: InputDecoration(
                hintText: 'بحث في كل الحقول...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _query = '';
                          _load();
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _empty(theme)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _card(_items[i], theme, scheme),
                  ),
                ),
    );
  }

  Widget _empty(ThemeData theme) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty ? 'لا توجد معلومات بعد' : 'لا نتائج للبحث',
              style: theme.textTheme.titleMedium,
            ),
            if (_query.isEmpty) ...[
              const SizedBox(height: 6),
              Text('اضغط «إضافة» لإنشاء أول معلومة',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ],
          ],
        ),
      );

  Widget _card(InfoEntry e, ThemeData theme, ColorScheme scheme) {
    final title = e.topic.isNotEmpty ? e.topic : e.brief;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(e),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.mainSpecialty.isNotEmpty || e.subSpecialty.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (e.mainSpecialty.isNotEmpty)
                      _tag(e.mainSpecialty, scheme.primaryContainer,
                          scheme.onPrimaryContainer),
                    if (e.subSpecialty.isNotEmpty)
                      _tag(e.subSpecialty, scheme.secondaryContainer,
                          scheme.onSecondaryContainer),
                  ],
                ),
              if (e.mainSpecialty.isNotEmpty || e.subSpecialty.isNotEmpty)
                const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (e.topic.isNotEmpty && e.brief.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  e.brief,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event, size: 13, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(_date(e.createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor)),
                  const Spacer(),
                  if (e.source.isNotEmpty)
                    Icon(Icons.link, size: 15, color: theme.hintColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
