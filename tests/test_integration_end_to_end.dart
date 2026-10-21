// ============================================================
// INTEGRATION PASSPORT — INT-1 End-to-End Test
// Version Stamp : v1.0.1  (patched from v1.0 — see PATCH NOTE below)
// Files: src/main.dart · src/app/app_shell.dart · src/app/routes.dart
//        src/app/wiring.dart · tests/test_integration_end_to_end.dart
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove the whole chain works through the real wiring: add a book,
//   log progress, build the widget payload, route a tap, round-trip a
//   backup, and hit the 6x6 wall. Uses an in-memory M1 and fakes for
//   every platform edge, so no plugin is called.
//
// M3 NOTE: the Progress Logger module has not been delivered, so the
//   wiring's M3 seam (ProgressLoggerPort) is exercised through its
//   temporary M1-backed stand-in.
// 2 AM HINT : `flutter test tests/test_integration_end_to_end.dart`.
//
// PATCH NOTE (v1.0.1)
//   Two adapter-file compile defects are fixed. They were invisible to
//   the module suites (which use fakes) and only appeared when wiring.dart
//   first imported the adapters:
//     1. m6_backup_vault_adapters.dart — the `cryptography` package also
//        exports a `Cipher`, colliding with M6's own `Cipher` port. The
//        crypto import is now prefixed `as crypto`.
//     2. m2_book_intake_adapters.dart — was written against a pre-13
//        file_picker API. It now uses the 13.1.0 static FilePicker.pickFile()
//        and PlatformFile.readAsBytes().
//   No module contract, error code or port definition changed.
// ============================================================

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/app/routes.dart';
import '../src/app/wiring.dart';
import '../src/modules/m1_library_store.dart';
import '../src/modules/m2_book_intake.dart';
import '../src/modules/m5_widget_bridge.dart';
import '../src/modules/m6_backup_vault.dart';

// ---------------------------------------------------------------
// Fakes for every platform edge
// ---------------------------------------------------------------

class FakeWidgetHost implements WidgetHost {
  Map<String, dynamic>? lastPayload;
  @override
  Future<void> writePayload(Map<String, dynamic> payload) async =>
      lastPayload = payload;
  @override
  Future<String> healthCheck() async => 'ok';
}

class FakeFileAccess implements FileAccess {
  FakeFileAccess({this.name = 'novel.pdf'});
  final String name;
  @override
  Future<PickedFile> pickAndRead() async =>
      PickedFile(name: name, bytes: List<int>.filled(4096, 1));
  @override
  Future<String> copyToAppStorage(String name, List<int> bytes) async =>
      '/app/storage/$name';
  @override
  Future<int> freeBytes() async => 1 << 40;
}

class FakeExtractor implements PageExtractor {
  FakeExtractor(this.pages);
  final int pages;
  @override
  Future<int> pageCount(String name, List<int> bytes) async => pages;
}

/// A fixed clock so M7's "today" matches the day the test logs against.
class FakeClock extends SystemClock {
  FakeClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// The M1 seam for M6. Snapshot reads the real catalog; replace REPLAYS
/// the snapshot through M1's add_book, because M1 v1.0.2 has no restore
/// API (M6 finding F1). This keeps the round-trip genuinely on M1.
class ReplayLibraryVault implements LibraryVaultPort {
  ReplayLibraryVault(this._store);
  final M1LibraryStore _store;

  @override
  Future<Map<String, dynamic>> snapshot() async {
    final Map<String, dynamic> r = await _store.handle(<String, dynamic>{
      'op': 'read_catalog',
      'payload': <String, dynamic>{},
      'idempotency_key': null,
      'schema_version': 1,
    });
    return (r['data'] as Map).cast<String, dynamic>();
  }

  @override
  Future<void> atomicReplace(Map<String, dynamic> snapshot) async {
    final List<dynamic> cats =
        (snapshot['categories'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic c in cats) {
      final Map<String, dynamic> cat = (c as Map).cast<String, dynamic>();
      final List<dynamic> books = (cat['books'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic b in books) {
        final Map<String, dynamic> m = (b as Map).cast<String, dynamic>();
        await _store.handle(<String, dynamic>{
          'op': 'add_book',
          'payload': <String, dynamic>{
            'book_id': m['book_id'],
            'category_id': cat['category_id'],
            'title': m['title'],
            'total_pages': m['total_pages'],
            'source': m['source'],
            'file_path': null,
            'cover_ref': m['cover_ref'],
          },
          'idempotency_key': 'restore-${m['book_id']}',
          'schema_version': 1,
        });
      }
    }
  }

  @override
  Future<String> healthCheck() => _store.healthCheck();
}

// ---------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------

Future<M1LibraryStore> freshM1() async {
  final M1LibraryStore s = M1LibraryStore(M1Database(NativeDatabase.memory()));
  await s.seedIfEmpty();
  return s;
}

int _seq = 0;
Future<String> addViaM2(AppWiring w, String categoryId) async {
  final Map<String, dynamic> r = await w.intake.handle(<String, dynamic>{
    'category_id': categoryId,
    'source': 'manual',
    'file_uri': null,
    'title': 'Book ${++_seq}',
    'total_pages': 100,
    'cover_ref': null,
    'idempotency_key': 'add-${_seq}',
  });
  expect(r['ok'], true, reason: '$r');
  return (r['data'] as Map)['book_id'] as String;
}

Future<String> firstCategoryId(AppWiring w) async {
  final Map<String, dynamic> r = await w.grid.handle(<String, dynamic>{'view': 'home'});
  return (((r['data'] as Map)['categories'] as List).first as Map)['category_id'] as String;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ---------------------------------------------------------------
  // E2E-1 — Add and see
  // ---------------------------------------------------------------
  test('E2E-1 — Add and see', () async {
    final M1LibraryStore m1 = await freshM1();
    final AppWiring w = AppWiring.forTest(store: m1, widgetHost: FakeWidgetHost());
    final String cat = await firstCategoryId(w);

    final String bookId = await addViaM2(w, cat);

    final Map<String, dynamic> home = await w.grid.handle(<String, dynamic>{'view': 'home'});
    final List<dynamic> cats = (home['data'] as Map)['categories'] as List<dynamic>;
    expect(cats.length, 6);
    final Map<String, dynamic> c1 = cats.firstWhere(
        (dynamic c) => (c as Map)['category_id'] == cat) as Map<String, dynamic>;
    expect(c1['book_count'], 1);
    expect(((c1['books'] as List).first as Map)['book_id'], bookId);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // E2E-2 — Log and reflect
  // ---------------------------------------------------------------
  test('E2E-2 — Log and reflect', () async {
    final M1LibraryStore m1 = await freshM1();
    final AppWiring w = AppWiring.forTest(
      store: m1,
      widgetHost: FakeWidgetHost(),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );
    final String cat = await firstCategoryId(w);
    final String bookId = await addViaM2(w, cat);

    // log progress through the M3 seam
    final Map<String, dynamic> logged =
        await w.progress.handle(<String, dynamic>{
      'book_id': bookId,
      'current_page': 40,
      'read_on': '2026-10-19',
      'idempotency_key': 'log-1',
    });
    expect(logged['ok'], true, reason: '$logged');

    // the day view reflects it
    final Map<String, dynamic> day = await w.daily.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': 330,
    });
    expect((day['data'] as Map)['total_pages_today'], 40);

    // the book tile reflects it
    final Map<String, dynamic> book =
        await w.grid.handle(<String, dynamic>{'view': 'book', 'book_id': bookId});
    expect((book['data'] as Map)['pct_today'], 40.0);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // E2E-3 — Widget payload
  // ---------------------------------------------------------------
  test('E2E-3 — Widget payload', () async {
    final M1LibraryStore m1 = await freshM1();
    final FakeWidgetHost host = FakeWidgetHost();
    final AppWiring w = AppWiring.forTest(store: m1, widgetHost: host);
    final String cat = await firstCategoryId(w);
    final String bookId = await addViaM2(w, cat);
    await w.progress.handle(<String, dynamic>{
      'book_id': bookId,
      'current_page': 25,
      'read_on': '2026-10-19',
      'idempotency_key': 'log-3',
    });

    // assemble the push payload: M4 day view + the shell's goal
    final Map<String, dynamic> day = await w.daily.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': 330,
    });
    final Map<String, dynamic> dd = (day['data'] as Map).cast<String, dynamic>();
    const int goal = 40; // from settings
    final List<Map<String, dynamic>> pcts = (dd['per_book'] as List)
        .map((dynamic e) => <String, dynamic>{
              'book_id': (e as Map)['book_id'],
              'pct': (e['pct_today'] as num).toDouble(),
            })
        .toList();

    final Map<String, dynamic> pushed = await w.widget.push(<String, dynamic>{
      'goal_pages': goal,
      'total_pages_today': dd['total_pages_today'],
      'per_book_pct': pcts,
    });
    expect(pushed['ok'], true, reason: '$pushed');
    expect(host.lastPayload!['goal_pages'], 40);
    expect(host.lastPayload!['total_pages_today'], 25);
    expect((host.lastPayload!['per_book_pct'] as List).length, 1);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // E2E-4 — Tap routing
  // ---------------------------------------------------------------
  test('E2E-4 — Tap routing', () async {
    final M1LibraryStore m1 = await freshM1();
    final AppWiring w = AppWiring.forTest(store: m1, widgetHost: FakeWidgetHost());

    final RouteTarget? b = w.routes.resolve('shelf://book/abc');
    expect(b, isNotNull);
    expect(b!.view, 'book');
    expect(b.id, 'abc');

    final RouteTarget? c = w.routes.resolve('shelf://category/xyz');
    expect(c, isNotNull);
    expect(c!.view, 'category');
    expect(c.id, 'xyz');

    expect(w.routes.resolve('https://example.com'), isNull);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // E2E-5 — Backup round-trip
  // ---------------------------------------------------------------
  test('E2E-5 — Backup round-trip', () async {
    final M1LibraryStore m1 = await freshM1();
    final AppWiring w = AppWiring.forTest(
      store: m1,
      widgetHost: FakeWidgetHost(),
      library: ReplayLibraryVault(m1),
    );
    final String cat = await firstCategoryId(w);
    await addViaM2(w, cat);
    await addViaM2(w, cat);

    Future<int> gridBookCount() async {
      final Map<String, dynamic> home =
          await w.grid.handle(<String, dynamic>{'view': 'home'});
      return (home['data'] as Map)['categories']
          .fold<int>(0, (int a, dynamic c) => a + ((c as Map)['books'] as List).length);
    }

    expect(await gridBookCount(), 2);

    // export
    final Map<String, dynamic> ex = await w.backup.export(<String, dynamic>{
      'destination_uri': '/shelf/backup.rtbk',
      'passphrase': 'correct-horse',
    });
    expect(ex['ok'], true, reason: '$ex');

    // wipe: delete every book through M1
    final Map<String, dynamic> home =
        await w.grid.handle(<String, dynamic>{'view': 'home'});
    for (final dynamic c in (home['data'] as Map)['categories'] as List<dynamic>) {
      for (final dynamic b in ((c as Map)['books'] as List<dynamic>)) {
        await m1.handle(<String, dynamic>{
          'op': 'delete_book',
          'payload': <String, dynamic>{'book_id': (b as Map)['book_id']},
          'idempotency_key': null,
          'schema_version': 1,
        });
      }
    }
    expect(await gridBookCount(), 0);

    // restore
    final Map<String, dynamic> rs = await w.backup.restore(<String, dynamic>{
      'source_uri': '/shelf/backup.rtbk',
      'passphrase': 'correct-horse',
    });
    expect(rs['ok'], true, reason: '$rs');

    // the grid is identical
    expect(await gridBookCount(), 2);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // E2E-6 — The 6x6 wall
  // ---------------------------------------------------------------
  test('E2E-6 — The 6x6 wall', () async {
    final M1LibraryStore m1 = await freshM1();
    final AppWiring w = AppWiring.forTest(store: m1, widgetHost: FakeWidgetHost());
    final String cat = await firstCategoryId(w);

    // a 7th book in a full category -> E3
    for (int i = 0; i < 6; i++) {
      await addViaM2(w, cat);
    }
    final Map<String, dynamic> seventh = await w.intake.handle(<String, dynamic>{
      'category_id': cat,
      'source': 'manual',
      'file_uri': null,
      'title': 'Seventh',
      'total_pages': 100,
      'cover_ref': null,
      'idempotency_key': 'seventh',
    });
    expect((seventh['error'] as Map)['code'], 'E3');

    // a 7th category -> E3 (M1 seeds 6; a new one is refused)
    final Map<String, dynamic> cat7 = await m1.handle(<String, dynamic>{
      'op': 'upsert_category',
      'payload': <String, dynamic>{
        'category_id': 'cat-7',
        'name': 'Category 7',
        'position': 0,
      },
      'idempotency_key': null,
      'schema_version': 1,
    });
    expect((cat7['error'] as Map)['code'], 'E3');

    await m1.db.close();
  });
}
