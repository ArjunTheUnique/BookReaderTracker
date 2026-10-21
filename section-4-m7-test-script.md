# SECTION 4 — TARGET TEST FILE PATH & RUNNABLE 5-PART VERIFICATION SCRIPT

Test File: tests/test_m7_grid_presenter.dart | Target Module: src/modules/m7_grid_presenter.dart

```dart
// ============================================================
// MODULE PASSPORT — M7 Grid Presenter (TEST)
// Version Stamp : v1.0
// Module File   : src/modules/m7_grid_presenter.dart
// Test File     : tests/test_m7_grid_presenter.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M7)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove M7 composes the home/category/book view-models from a real
//   M1 catalog and a real M4 day view, enforces the 6x6 shape, and
//   returns E1/E4 correctly. M7 is read-only.
// 2 AM HINT : `flutter test tests/test_m7_grid_presenter.dart`.
// ============================================================

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/modules/m1_library_store.dart';
// M4 and M7 each declare their own Clock/Catalog/Daily ports, so the test
// uses import prefixes to keep them apart (see Section 5, F3).
import '../src/modules/m4_daily_engine.dart' as engine;
import '../src/modules/m7_grid_presenter.dart' as grid;

// ---------------------------------------------------------------
// Adapters + clock
// ---------------------------------------------------------------

class FakeClock implements engine.Clock, grid.Clock {
  FakeClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

class M1CatalogAdapter implements grid.CatalogPort {
  M1CatalogAdapter(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

class M1DailySourceAdapter implements engine.DailySourcePort {
  M1DailySourceAdapter(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

class M4DailyViewAdapter implements grid.DailyViewPort {
  M4DailyViewAdapter(this._m4);
  final engine.M4DailyEngine _m4;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _m4.handle(e);
  @override
  Future<String> healthCheck() => _m4.healthCheck();
}

// ---------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------

Map<String, dynamic> m1env(String op, Map<String, dynamic> payload, {String? idem}) =>
    <String, dynamic>{
      'op': op,
      'payload': payload,
      'idempotency_key': idem,
      'schema_version': 1,
    };

Future<M1LibraryStore> freshM1() async {
  final M1LibraryStore s = M1LibraryStore(M1Database(NativeDatabase.memory()));
  await s.seedIfEmpty();
  return s;
}

Future<List<String>> categoryIds(M1LibraryStore m1) async {
  final Map<String, dynamic> r = await m1.handle(m1env('read_catalog', <String, dynamic>{}));
  final List<dynamic> cats = (r['data'] as Map)['categories'] as List<dynamic>;
  return cats.map((dynamic c) => (c as Map)['category_id'] as String).toList();
}

int _seq = 0;
Future<String> addBook(M1LibraryStore m1, String cat, {int totalPages = 100}) async {
  final String id = 'bk-${++_seq}';
  final Map<String, dynamic> r = await m1.handle(m1env('add_book', <String, dynamic>{
    'book_id': id,
    'category_id': cat,
    'title': 'Book $id',
    'total_pages': totalPages,
    'source': 'manual',
    'file_path': null,
    'cover_ref': null,
  }, idem: 'ab-$id'));
  expect(r['ok'], true, reason: '$r');
  return id;
}

grid.M7GridPresenter buildM7(M1LibraryStore m1, FakeClock clock) {
  final engine.M4DailyEngine daily =
      engine.M4DailyEngine(m1: M1DailySourceAdapter(m1), clock: clock);
  return grid.M7GridPresenter(
    catalog: M1CatalogAdapter(m1),
    daily: M4DailyViewAdapter(daily),
    clock: clock,
    timezoneOffsetMin: 330,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ---------------------------------------------------------------
  // TEST 1 — Happy-Path Acceptance
  // ---------------------------------------------------------------
  test('Test 1 — Happy-Path Acceptance', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = (await categoryIds(m1)).first;
    final String book = await addBook(m1, cat, totalPages: 100);
    await m1.handle(m1env('update_progress', <String, dynamic>{
      'book_id': book,
      'current_page': 50,
      'read_on': '2026-10-19',
    }, idem: 'p1'));

    final grid.M7GridPresenter m7 =
        buildM7(m1, FakeClock(DateTime.utc(2026, 10, 19, 12)));
    final Map<String, dynamic> r = await m7.handle(<String, dynamic>{'view': 'home'});
    expect(r['ok'], true, reason: '$r');
    final List<dynamic> cats = (r['data'] as Map)['categories'] as List<dynamic>;
    expect(cats.length, 6);
    final Map<String, dynamic> c1 = (cats.first as Map).cast<String, dynamic>();
    expect(c1['book_count'], 1);
    final Map<String, dynamic> b1 =
        ((c1['books'] as List).first as Map).cast<String, dynamic>();
    expect(b1['book_id'], book);
    expect(b1['pct_today'], 50.0);
    expect(b1['title'], isA<String>());

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 2 — Boundary & Idempotency Breaker
  // ---------------------------------------------------------------
  test('Test 2 — Boundary & Idempotency Breaker', () async {
    final M1LibraryStore m1 = await freshM1();
    final grid.M7GridPresenter m7 =
        buildM7(m1, FakeClock(DateTime.utc(2026, 10, 19, 12)));

    // (a) empty catalog -> 6 empty tiles, SUCCESS not error
    final Map<String, dynamic> empty = await m7.handle(<String, dynamic>{'view': 'home'});
    expect(empty['ok'], true, reason: '$empty');
    final List<dynamic> cats = (empty['data'] as Map)['categories'] as List<dynamic>;
    expect(cats.length, 6);
    for (final dynamic c in cats) {
      expect(((c as Map)['books'] as List).isEmpty, true);
      expect(c['book_count'], 0);
    }

    // (b) a full category shows exactly 6 books
    final String cat = (await categoryIds(m1)).first;
    for (int i = 0; i < 6; i++) {
      await addBook(m1, cat);
    }
    final Map<String, dynamic> full = await m7.handle(
        <String, dynamic>{'view': 'category', 'category_id': cat});
    expect(full['ok'], true, reason: '$full');
    expect((full['data'] as Map)['book_count'], 6);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 3 — Explicit Error-Shape Coverage (E1, E4)
  // ---------------------------------------------------------------
  test('Test 3 — Explicit Error-Shape Coverage', () async {
    final M1LibraryStore m1 = await freshM1();
    final grid.M7GridPresenter m7 =
        buildM7(m1, FakeClock(DateTime.utc(2026, 10, 19, 12)));

    // E1 — bad view
    final Map<String, dynamic> e1 =
        await m7.handle(<String, dynamic>{'view': 'shelf'});
    expect((e1['error'] as Map)['code'], 'E1');

    // E1 — missing id for the view
    final Map<String, dynamic> e1b = await m7.handle(<String, dynamic>{'view': 'category'});
    expect((e1b['error'] as Map)['code'], 'E1');

    // E4 — unknown category
    final Map<String, dynamic> e4 = await m7.handle(
        <String, dynamic>{'view': 'category', 'category_id': 'ghost'});
    expect((e4['error'] as Map)['code'], 'E4');

    // E4 — unknown book
    final Map<String, dynamic> e4b =
        await m7.handle(<String, dynamic>{'view': 'book', 'book_id': 'ghost'});
    expect((e4b['error'] as Map)['code'], 'E4');

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 4 — Registry Seam Contract Test
  // ---------------------------------------------------------------
  test('Test 4 — Registry Seam Contract Test', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = (await categoryIds(m1)).first;
    await addBook(m1, cat);
    final grid.M7GridPresenter m7 =
        buildM7(m1, FakeClock(DateTime.utc(2026, 10, 19, 12)));

    final Map<String, dynamic> home = await m7.handle(<String, dynamic>{'view': 'home'});
    final Map<String, dynamic> hd = (home['data'] as Map).cast<String, dynamic>();
    expect(hd.keys.toSet(), <String>{'categories'});
    final Map<String, dynamic> c1 =
        ((hd['categories'] as List).first as Map).cast<String, dynamic>();
    expect(c1.keys.toSet(),
        <String>{'category_id', 'name', 'book_count', 'books'});
    final Map<String, dynamic> b1 =
        ((c1['books'] as List).first as Map).cast<String, dynamic>();
    expect(b1.keys.toSet(),
        <String>{'book_id', 'title', 'cover_ref', 'pct_today'});
    expect(b1['pct_today'], isA<double>());
    expect(home['schema_version'], 1);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 5 — End-to-End Smoke & Health-Check Probe
  // ---------------------------------------------------------------
  test('Test 5 — End-to-End Smoke & Health-Check Probe', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = (await categoryIds(m1)).first;
    final String book = await addBook(m1, cat);
    await m1.handle(m1env('update_progress', <String, dynamic>{
      'book_id': book,
      'current_page': 30,
      'read_on': '2026-10-19',
    }, idem: 'p5'));

    final grid.M7GridPresenter m7 =
        buildM7(m1, FakeClock(DateTime.utc(2026, 10, 19, 12)));
    expect(await m7.healthCheck(), 'ok');

    // all three views render end to end
    final Map<String, dynamic> home = await m7.handle(<String, dynamic>{'view': 'home'});
    expect(home['ok'], true, reason: '$home');
    final Map<String, dynamic> catView = await m7.handle(
        <String, dynamic>{'view': 'category', 'category_id': cat});
    expect(catView['ok'], true, reason: '$catView');
    final Map<String, dynamic> bookView =
        await m7.handle(<String, dynamic>{'view': 'book', 'book_id': book});
    expect(bookView['ok'], true, reason: '$bookView');
    expect((bookView['data'] as Map)['pct_today'], 30.0);

    await m1.db.close();
  });
}
```

## Run it

1. `flutter pub get`  2. ensure `build.yaml` exists  3. `dart run build_runner build` then `flutter test tests/test_m7_grid_presenter.dart`.
