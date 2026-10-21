// ============================================================
// INTEGRATION FILE — INT-1 src/app/app_shell.dart
// Version Stamp : v1.0
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   This is the product's face: the 6x6 no-scroll shelf. It reads
//   view-models from M7 ONLY (home / category / book). It never
//   queries the database and never computes a percentage itself.
//
// SAFE TO EDIT : layout, colours, copy, tile sizes.
// DO NOT TOUCH : the goal_pages source, the routes, and the rule that
//   the UI reads view-models from M7 only.
// ============================================================

import 'package:flutter/material.dart';

import 'routes.dart';
import 'wiring.dart';

/// The app root.
class ShelfApp extends StatelessWidget {
  ShelfApp({super.key, required this.wiring});

  final AppWiring wiring;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelf',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFC2410C),
      ),
      home: ShelfShell(wiring: wiring),
    );
  }
}

/// The shell: home grid, category, book, add-book and settings.
class ShelfShell extends StatefulWidget {
  ShelfShell({super.key, required this.wiring});

  final AppWiring wiring;

  @override
  State<ShelfShell> createState() => _ShelfShellState();
}

class _ShelfShellState extends State<ShelfShell> {
  String _view = 'home';
  String? _categoryId;
  String? _bookId;
  Map<String, dynamic> _data = <String, dynamic>{};
  String _status = 'booting…';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final String health = await widget.wiring.bootHealth();
    if (!mounted) return;
    setState(() => _status = health);
    if (health == 'ok') {
      await _load('home');
    }
  }

  Future<void> _load(String view, {String? categoryId, String? bookId}) async {
    final Map<String, dynamic> request = <String, dynamic>{'view': view};
    if (categoryId != null) request['category_id'] = categoryId;
    if (bookId != null) request['book_id'] = bookId;
    final Map<String, dynamic> r = await widget.wiring.grid.handle(request);
    if (!mounted) return;
    if (r['ok'] == true) {
      setState(() {
        _view = view;
        _categoryId = categoryId;
        _bookId = bookId;
        _data = (r['data'] as Map).cast<String, dynamic>();
        _status = 'ok';
      });
    } else {
      setState(() => _status = 'error ${(r['error'] as Map)['code']}');
    }
  }

  /// Open the screen a widget tap asked for (deep link).
  Future<void> openRoute(String route) async {
    final RouteTarget? target = widget.wiring.routes.resolve(route);
    if (target == null) {
      await _load('home');
      return;
    }
    if (target.view == 'book') {
      await _load('book', bookId: target.id);
    } else {
      await _load('category', categoryId: target.id);
    }
  }

  Future<void> _logProgress(String bookId) async {
    final TextEditingController page = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Log progress'),
        content: TextField(
          controller: page,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Current page'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (go != true) return;
    final DateTime now = widget.wiring.clock.now();
    final String readOn = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final Map<String, dynamic> r =
        await widget.wiring.progress.handle(<String, dynamic>{
      'book_id': bookId,
      'current_page': int.tryParse(page.text.trim()) ?? 0,
      'read_on': readOn,
      'idempotency_key': 'ui-$bookId-$readOn-${page.text.trim()}',
    });
    if (!mounted) return;
    setState(() => _status =
        r['ok'] == true ? 'logged' : 'error ${(r['error'] as Map)['code']}');
    await _load('book', bookId: bookId);
  }

  Future<void> _exportBackup() async {
    final Map<String, dynamic> r =
        await widget.wiring.backup.export(<String, dynamic>{
      'destination_uri': '/shelf/backup.rtbk',
      'passphrase': 'correct-horse',
    });
    if (!mounted) return;
    setState(() => _status =
        r['ok'] == true ? 'backup written' : 'error ${(r['error'] as Map)['code']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title()),
        leading: _view == 'home'
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _load('home'),
              ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _load('home').then((_) => _showSettings()),
          ),
        ],
      ),
      body: _body(),
      floatingActionButton: _view == 'category' && _categoryId != null
          ? FloatingActionButton(
              onPressed: () => _addBook(_categoryId!),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(_status, textAlign: TextAlign.center),
      ),
    );
  }

  String _title() {
    switch (_view) {
      case 'category':
        return (_data['name'] as String?) ?? 'Category';
      case 'book':
        return (_data['title'] as String?) ?? 'Book';
      default:
        return 'Shelf';
    }
  }

  Widget _body() {
    switch (_view) {
      case 'category':
        return _bookList();
      case 'book':
        return _bookView();
      default:
        return _homeGrid();
    }
  }

  /// Home — exactly 6 tiles, no scrolling.
  Widget _homeGrid() {
    final List<dynamic> cats =
        (_data['categories'] as List<dynamic>?) ?? const <dynamic>[];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        physics: const NeverScrollableScrollPhysics(),
        children: cats.map((dynamic c) {
          final Map<String, dynamic> m = (c as Map).cast<String, dynamic>();
          return _tile(
            title: (m['name'] as String?) ?? 'Category',
            subtitle: '${m['book_count']} / 6',
            onTap: () => _load('category', categoryId: m['category_id'] as String),
          );
        }).toList(),
      ),
    );
  }

  Widget _bookList() {
    final List<dynamic> books =
        (_data['books'] as List<dynamic>?) ?? const <dynamic>[];
    return ListView(
      children: books.map((dynamic b) {
        final Map<String, dynamic> m = (b as Map).cast<String, dynamic>();
        return ListTile(
          title: Text((m['title'] as String?) ?? 'Book'),
          subtitle: Text('${_pct(m)}% today'),
          onTap: () => _load('book', bookId: m['book_id'] as String),
        );
      }).toList(),
    );
  }

  Widget _bookView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text((_data['title'] as String?) ?? 'Book',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('${_pct(_data)}% read today'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _logProgress(_data['book_id'] as String),
            child: const Text('Log progress'),
          ),
        ],
      ),
    );
  }

  String _pct(Map<String, dynamic> m) {
    final Object? p = m['pct_today'];
    return p is num ? p.toStringAsFixed(0) : '0';
  }

  Widget _tile(
      {required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addBook(String categoryId) async {
    final TextEditingController title = TextEditingController();
    final TextEditingController pages = TextEditingController();
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add a book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title')),
            TextField(
                controller: pages,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total pages')),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (go != true) return;
    final Map<String, dynamic> r =
        await widget.wiring.intake.handle(<String, dynamic>{
      'category_id': categoryId,
      'source': 'manual',
      'file_uri': null,
      'title': title.text.trim(),
      'total_pages': int.tryParse(pages.text.trim()) ?? 0,
      'cover_ref': null,
      'idempotency_key': 'ui-add-${title.text.trim()}',
    });
    if (!mounted) return;
    setState(() => _status =
        r['ok'] == true ? 'added' : 'error ${(r['error'] as Map)['code']}');
    await _load('category', categoryId: categoryId);
  }

  Future<void> _showSettings() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Daily goal and backup are configured here.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exportBackup();
            },
            child: const Text('Export backup'),
          ),
        ],
      ),
    );
  }
}
