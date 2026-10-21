# SECTION 4 — TARGET TEST FILE PATH & RUNNABLE 5-PART VERIFICATION SCRIPT

Test File: tests/test_m1_library_store.dart | Target Module: src/modules/m1_library_store.dart

Version: v1.0.2.

```dart
// ============================================================
// MODULE PASSPORT — M1 Library Store (TEST)
// Version Stamp : v1.0.2  (patched from v1.0.1)
// Module File   : src/modules/m1_library_store.dart
// Test File     : tests/test_m1_library_store.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.0 (Table 2A, row M1)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove, in one command, that M1 honours its IN/OUT socket, its
//   error shapes E1..E7, its idempotency rule and its 6/6 caps.
// MACHINE SOCKET CONTRACT SUMMARY
//   Same envelope as the module. This file only READS results.
// CONTROL PATH SUMMARY
//   Exercises switches C1 (seed) and C2 (capacity) indirectly.
// DATA PATH SUMMARY
//   Uses an in-memory Drift DB so no file is touched.
// SAFE TO EDIT
//   Sample book titles, page counts and dates below.
// DO NOT TOUCH
//   The expected field names, error codes and the 6/6 caps.
// 2 AM TROUBLESHOOTING HINT
//   Run from the project root: `flutter test tests/test_m1_library_store.dart`.
//   If it fails to COMPILE with "part 'm1_library_store.g.dart' not found",
//   you forgot `dart run build_runner build` first.
// ============================================================

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/modules/m1_library_store.dart';

/// Build a well-formed operation envelope.
Map<String, dynamic> env(
  String op,
  Map<String, dynamic> payload, {
  String? idem,
  int sv = 1,
}) =>
    <String, dynamic>{
      'op': op,
      'payload': payload,
      'idempotency_key': idem,
      'schema_version': sv,
    };

/// A fresh in-memory store, seeded so the grid has 6 tiles (C1).
Future<M1LibraryStore> freshStore() async {
  final M1LibraryStore store = M1LibraryStore(M1Database(NativeDatabase.memory()));
  await store.seedIfEmpty();
  return store;
}

/// Read the first category id out of a read_catalog result.
Future<String> firstCategoryId(M1LibraryStore store) async {
  final Map<String, dynamic> res = await store.handle(env('read_catalog', {}));
  final List<dynamic> cats = (res['data'] as Map)['categories'] as List<dynamic>;
  return (cats.first as Map)['category_id'] as String;
}

/// Add one manual book and return the raw result.
Future<Map<String, dynamic>> addManual(
  M1LibraryStore store, {
  required String bookId,
  required String categoryId,
  String? title,
  int totalPages = 100,
  String idem = '',
}) =>
    store.handle(env(
      'add_book',
      <String, dynamic>{
        'book_id': bookId,
        'category_id': categoryId,
        'title': title ?? 'Book $bookId',
        'total_pages': totalPages,
        'source': 'manual',
        'file_path': null,
        'cover_ref': null,
      },
      idem: idem.isEmpty ? 'idem-$bookId' : idem,
    ));

void main() {
  // ---------------------------------------------------------------
  // TEST 1 — Happy-Path Acceptance
  // ---------------------------------------------------------------
  test('Test 1 — Happy-Path Acceptance', () async {
    final M1LibraryStore store = await freshStore();
    final String cat1 = await firstCategoryId(store);

    for (int i = 1; i <= 6; i++) {
      final Map<String, dynamic> r = await addManual(
        store,
        bookId: 'book-$i',
        categoryId: cat1,
        title: 'Book $i',
        totalPages: 100 * i,
      );
      expect(r['ok'], true, reason: 'add_book $i should succeed: $r');
      expect((r['data'] as Map)['book_count'], i);
    }

    final Map<String, dynamic> up = await store.handle(env(
      'update_progress',
      <String, dynamic>{
        'book_id': 'book-1',
        'current_page': 50,
        'read_on': '2026-10-19',
      },
      idem: 'prog-1',
    ));
    expect(up['ok'], true, reason: '$up');
    expect((up['data'] as Map)['saved'], true);
    expect((up['data'] as Map)['pct_read'], 50.0);

    final Map<String, dynamic> cat = await store.handle(env('read_catalog', {}));
    final List<dynamic> cats = (cat['data'] as Map)['categories'] as List<dynamic>;
    expect(cats.length, 6, reason: 'exactly 6 categories');
    final Map<dynamic, dynamic> c1 = cats.first as Map;
    expect((c1['books'] as List).length, 6, reason: 'category 1 holds 6 books');
    expect((cat['data'] as Map)['categories'], isNotNull);

    await store.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 2 — Boundary & Idempotency Breaker
  // ---------------------------------------------------------------
  test('Test 2 — Boundary & Idempotency Breaker', () async {
    final M1LibraryStore store = await freshStore();

    // 7th category is refused with E3.
    final Map<String, dynamic> r7 = await store.handle(env(
      'upsert_category',
      <String, dynamic>{'category_id': 'cat-7', 'name': 'Category 7', 'position': 0},
    ));
    expect((r7['error'] as Map)['code'], 'E3');

    // Fill category 1, then a 7th book is refused with E3.
    final String cat1 = await firstCategoryId(store);
    for (int i = 1; i <= 6; i++) {
      await addManual(store, bookId: 'b$i', categoryId: cat1, totalPages: 10);
    }
    final Map<String, dynamic> r7b = await addManual(
      store,
      bookId: 'b7',
      categoryId: cat1,
      totalPages: 10,
      idem: 'idem-b7',
    );
    expect((r7b['error'] as Map)['code'], 'E3');

    // Repeated idempotency key: first write saved:true, replay saved:false,
    // and the progress row count is unchanged.
    final Map<String, dynamic> p1 = await store.handle(env(
      'update_progress',
      <String, dynamic>{'book_id': 'b1', 'current_page': 5, 'read_on': '2026-10-19'},
      idem: 'prog-key',
    ));
    expect((p1['data'] as Map)['saved'], true);
    final Map<String, dynamic> p2 = await store.handle(env(
      'update_progress',
      <String, dynamic>{'book_id': 'b1', 'current_page': 5, 'read_on': '2026-10-19'},
      idem: 'prog-key',
    ));
    expect((p2['data'] as Map)['saved'], false);
    final List<ProgressLogData> rows = await store.db.select(store.db.progressLog).get();
    expect(rows.length, 1, reason: 'replay must not write a second row');

    // Fix C regression: the SAME key string reused across two DIFFERENT
    // operations must NOT be mis-read as a replay. Category 1 is full, so
    // use the second category for the add_book leg.
    final Map<String, dynamic> catRes = await store.handle(env('read_catalog', {}));
    final List<dynamic> allCats = (catRes['data'] as Map)['categories'] as List<dynamic>;
    final String cat2 = (allCats[1] as Map)['category_id'] as String;

    final Map<String, dynamic> crossAdd = await store.handle(env(
      'add_book',
      <String, dynamic>{
        'book_id': 'x1', 'category_id': cat2, 'title': 'X1',
        'total_pages': 10, 'source': 'manual', 'file_path': null, 'cover_ref': null,
      },
      idem: 'shared-key',
    ));
    expect(crossAdd['ok'], true, reason: 'add_book with reused key: $crossAdd');

    final Map<String, dynamic> crossProg = await store.handle(env(
      'update_progress',
      <String, dynamic>{'book_id': 'b1', 'current_page': 7, 'read_on': '2026-10-20'},
      idem: 'shared-key',
    ));
    expect(crossProg['ok'], true, reason: '$crossProg');
    expect((crossProg['data'] as Map)['saved'], true,
        reason: 'same key, different op, must NOT be treated as a replay');
    final List<ProgressLogData> rows2 = await store.db.select(store.db.progressLog).get();
    expect(rows2.length, 2, reason: 'the cross-op write must land');

    await store.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 3 — Explicit Error-Shape Coverage (E1,E2,E3,E4,E5,E7)
  // ---------------------------------------------------------------
  test('Test 3 — Explicit Error-Shape Coverage', () async {
    final M1LibraryStore store = await freshStore();
    final String cat1 = await firstCategoryId(store);

    // E1 — unknown op.
    final Map<String, dynamic> e1 = await store.handle(env('explode', <String, dynamic>{}));
    expect((e1['error'] as Map)['code'], 'E1');

    // E2 — total_pages out of range.
    final Map<String, dynamic> e2 = await store.handle(env(
      'add_book',
      <String, dynamic>{
        'book_id': 'x', 'category_id': cat1, 'title': 'X',
        'total_pages': 0, 'source': 'manual', 'file_path': null, 'cover_ref': null,
      },
      idem: 'k-e2',
    ));
    expect((e2['error'] as Map)['code'], 'E2');

    // E3 — 7th category.
    final Map<String, dynamic> e3 = await store.handle(env(
      'upsert_category',
      <String, dynamic>{'category_id': 'c7', 'name': 'C7', 'position': 0},
    ));
    expect((e3['error'] as Map)['code'], 'E3');

    // E4 — add a book to a category that does not exist.
    final Map<String, dynamic> e4 = await store.handle(env(
      'add_book',
      <String, dynamic>{
        'book_id': 'n', 'category_id': 'ghost', 'title': 'N',
        'total_pages': 10, 'source': 'manual', 'file_path': null, 'cover_ref': null,
      },
      idem: 'k-e4',
    ));
    expect((e4['error'] as Map)['code'], 'E4');

    // E5 — duplicate book_id.
    await addManual(store, bookId: 'dup', categoryId: cat1, totalPages: 10);
    final Map<String, dynamic> e5 = await store.handle(env(
      'add_book',
      <String, dynamic>{
        'book_id': 'dup', 'category_id': cat1, 'title': 'Dup',
        'total_pages': 10, 'source': 'manual', 'file_path': null, 'cover_ref': null,
      },
      idem: 'k-e5',
    ));
    expect((e5['error'] as Map)['code'], 'E5');

    // E7 — storage fault: close the DB, then any read fails safely.
    await store.db.close();
    final Map<String, dynamic> e7 = await store.handle(env('read_catalog', {}));
    expect((e7['error'] as Map)['code'], 'E7');
  });

  // ---------------------------------------------------------------
  // TEST 4 — Registry Seam Contract Test
  // ---------------------------------------------------------------
  test('Test 4 — Registry Seam Contract Test', () async {
    final M1LibraryStore store = await freshStore();
    final String cat1 = await firstCategoryId(store);

    // Rename an EXISTING tile (creating a new one when 6 exist is E3).
    final Map<String, dynamic> up = await store.handle(env(
      'upsert_category',
      <String, dynamic>{'category_id': cat1, 'name': 'Renamed', 'position': 0},
    ));
    expect((up['data'] as Map).keys.toSet(), {'category_id'});

    final Map<String, dynamic> ab = await addManual(
        store, bookId: 'bk', categoryId: cat1, totalPages: 10);
    expect((ab['data'] as Map).keys.toSet(), {'book_id', 'category_id', 'book_count'});
    expect((ab['data'] as Map)['book_count'], isA<int>());

    final Map<String, dynamic> pg = await store.handle(env(
      'update_progress',
      <String, dynamic>{'book_id': 'bk', 'current_page': 5, 'read_on': '2026-10-19'},
      idem: 'seam-1',
    ));
    expect((pg['data'] as Map).keys.toSet(),
        {'book_id', 'current_page', 'pct_read', 'saved'});
    expect((pg['data'] as Map)['pct_read'], isA<double>());
    expect((pg['data'] as Map)['saved'], isA<bool>());

    final Map<String, dynamic> rc = await store.handle(env('read_catalog', {}));
    expect((rc['data'] as Map).keys.toSet(), {'categories'});

    final Map<String, dynamic> rd = await store.handle(env(
      'read_daily',
      <String, dynamic>{'as_of_date': '2026-10-19'},
    ));
    expect((rd['data'] as Map).keys.toSet(),
        {'date', 'total_pages_today', 'per_book'});
    expect((rd['data'] as Map)['total_pages_today'], isA<int>());

    final Map<String, dynamic> db = await store.handle(env(
      'delete_book',
      <String, dynamic>{'book_id': 'bk'},
    ));
    expect((db['data'] as Map).keys.toSet(), {'book_id', 'deleted'});
    expect((db['data'] as Map)['deleted'], true);

    // schema_version on every success.
    for (final Map<String, dynamic> r in <Map<String, dynamic>>[up, ab, pg, rc, rd, db]) {
      expect(r['schema_version'], 1);
    }

    await store.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 5 — End-to-End Smoke & Health-Check Probe
  // ---------------------------------------------------------------
  test('Test 5 — End-to-End Smoke & Health-Check Probe', () async {
    final M1LibraryStore store = await freshStore();

    expect(await store.healthCheck(), 'ok');

    final Map<String, dynamic> rc = await store.handle(env('read_catalog', {}));
    final List<dynamic> cats = (rc['data'] as Map)['categories'] as List<dynamic>;
    expect(cats.length, 6);
    for (final dynamic c in cats) {
      expect((c as Map)['books'], isEmpty);
    }

    await store.db.close();
  });
}
```

## Run it in 10 seconds, from the project root

1. `flutter pub get` — resolves the pinned packages and writes `pubspec.lock`.
2. Make sure `build.yaml` exists in the project root (see Section 2) — without it, the
   generator writes zero outputs because the module sits in `src/modules/`.
3. `dart run build_runner build` — generates `src/modules/m1_library_store.g.dart`.
4. `flutter test tests/test_m1_library_store.dart` — runs all five checks; a green run
   prints `All tests passed!`.
