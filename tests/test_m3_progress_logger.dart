// ============================================================
// MODULE PASSPORT — M3 Progress Logger (TEST)
// Version Stamp : v1.0
// Module File   : src/modules/m3_progress_logger.dart
// Test File     : tests/test_m3_progress_logger.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M3)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove M3 honours its IN/OUT socket, its error shapes E1/E2/E4/E5,
//   its idempotency guard, and the M1 delegation — using a real
//   in-memory M1 and an injected fake Clock.
// SAFE TO EDIT   : sample page numbers and ids below.
// DO NOT TOUCH   : expected field names, error codes.
// 2 AM HINT      : `flutter test tests/test_m3_progress_logger.dart`.
// ============================================================

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/modules/m1_library_store.dart';
import '../src/modules/m3_progress_logger.dart';

// ---------------------------------------------------------------
// Doubles
// ---------------------------------------------------------------

/// A fixed clock so "today" is deterministic.
class FakeClock implements Clock {
  FakeClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// The M1 seam: forwards straight to a real M1.
class M1ProgressStore implements ProgressStorePort {
  M1ProgressStore(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

/// A stub that always answers E5, to prove M3 passes a store-reported
/// duplicate through UNCHANGED (see Section 5, finding F2).
class DuplicateStore implements ProgressStorePort {
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) async =>
      <String, dynamic>{
        'ok': false,
        'error': <String, dynamic>{
          'code': 'E5',
          'message': 'a genuine duplicate',
          'field': 'book_id',
        },
      };
  @override
  Future<String> healthCheck() async => 'ok';
}

// ---------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------

Map<String, dynamic> env(String op, Map<String, dynamic> payload, {String? idem}) =>
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

Future<String> firstCategoryId(M1LibraryStore m1) async {
  final Map<String, dynamic> r =
      await m1.handle(env('read_catalog', <String, dynamic>{}));
  return (((r['data'] as Map)['categories'] as List).first as Map)['category_id']
      as String;
}

int _seq = 0;
Future<String> addBook(M1LibraryStore m1, String cat, {int totalPages = 100}) async {
  final String id = 'bk-${++_seq}';
  final Map<String, dynamic> r = await m1.handle(env('add_book', <String, dynamic>{
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

M3ProgressLogger buildM3(M1LibraryStore m1, {Clock? clock}) => M3ProgressLogger(
      store: M1ProgressStore(m1),
      clock: clock ?? FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );

Map<String, dynamic> input(String bookId,
        {Object page = 40, String readOn = '2026-10-19'}) =>
    <String, dynamic>{
      'book_id': bookId,
      'current_page': page,
      'read_on': readOn,
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ---------------------------------------------------------------
  // TEST 1 — Happy-Path Acceptance
  // ---------------------------------------------------------------
  test('Test 1 — Happy-Path Acceptance', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = await firstCategoryId(m1);
    final String book = await addBook(m1, cat, totalPages: 100);
    final M3ProgressLogger m3 = buildM3(m1);

    final Map<String, dynamic> r = await m3.handle(input(book, page: 40));
    expect(r['ok'], true, reason: '$r');
    final Map<String, dynamic> d = (r['data'] as Map).cast<String, dynamic>();
    expect(d['book_id'], book);
    expect(d['current_page'], 40);
    expect(d['pct_read'], 40.0);
    expect(d['saved'], true);

    // the row really landed in M1
    final Map<String, dynamic> day =
        await m1.handle(env('read_daily', <String, dynamic>{
      'as_of_date': '2026-10-19',
    }));
    expect((day['data'] as Map)['total_pages_today'], 40);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 2 — Boundary & Idempotency Breaker
  // ---------------------------------------------------------------
  test('Test 2 — Boundary & Idempotency Breaker', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = await firstCategoryId(m1);
    final String book = await addBook(m1, cat, totalPages: 100);
    final M3ProgressLogger m3 = buildM3(m1);

    // (a) out of range -> E2
    final Map<String, dynamic> oor = await m3.handle(input(book, page: 200));
    expect((oor['error'] as Map)['code'], 'E2');

    // (b) the same logical save twice -> one row, second saved:false
    final Map<String, dynamic> first = await m3.handle(input(book, page: 40));
    final Map<String, dynamic> second = await m3.handle(input(book, page: 40));
    expect((first['data'] as Map)['saved'], true);
    expect((second['data'] as Map)['saved'], false);
    expect((second['data'] as Map)['pct_read'], 40.0);

    final List<dynamic> rows = await m1.db.select(m1.db.progressLog).get();
    expect(rows.length, 1, reason: 'a double-tap must produce one row, not two');

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 3 — Explicit Error-Shape Coverage (E1, E2, E4, E5)
  // ---------------------------------------------------------------
  test('Test 3 — Explicit Error-Shape Coverage', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = await firstCategoryId(m1);
    final String book = await addBook(m1, cat, totalPages: 100);
    final M3ProgressLogger m3 = buildM3(m1);

    // E1 — wrong type
    final Map<String, dynamic> e1 = await m3.handle(input(book, page: 'forty'));
    expect((e1['error'] as Map)['code'], 'E1');

    // E1 — malformed date
    final Map<String, dynamic> e1b =
        await m3.handle(input(book, readOn: '2026-13-40'));
    expect((e1b['error'] as Map)['code'], 'E1');

    // E1 — future date (uses the injected Clock)
    final Map<String, dynamic> e1c =
        await m3.handle(input(book, readOn: '2099-01-01'));
    expect((e1c['error'] as Map)['code'], 'E1');

    // E2 — page outside the book
    final Map<String, dynamic> e2 = await m3.handle(input(book, page: 999));
    expect((e2['error'] as Map)['code'], 'E2');

    // E4 — the book does not exist
    final Map<String, dynamic> e4 = await m3.handle(input('ghost'));
    expect((e4['error'] as Map)['code'], 'E4');

    // E5 — a store-reported duplicate, passed through unchanged
    final M3ProgressLogger m3dup = M3ProgressLogger(
      store: DuplicateStore(),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );
    final Map<String, dynamic> e5 = await m3dup.handle(input(book));
    expect((e5['error'] as Map)['code'], 'E5');

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 4 — Registry Seam Contract Test
  // ---------------------------------------------------------------
  test('Test 4 — Registry Seam Contract Test', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = await firstCategoryId(m1);
    final String book = await addBook(m1, cat, totalPages: 200);
    final M3ProgressLogger m3 = buildM3(m1);

    final Map<String, dynamic> r = await m3.handle(input(book, page: 50));
    expect(r['ok'], true, reason: '$r');
    final Map<String, dynamic> d = (r['data'] as Map).cast<String, dynamic>();
    expect(d.keys.toSet(),
        <String>{'book_id', 'current_page', 'pct_read', 'saved'});
    expect(d['book_id'], isA<String>());
    expect(d['current_page'], isA<int>());
    expect(d['pct_read'], isA<double>());
    expect(d['saved'], isA<bool>());
    expect(r['schema_version'], 1);

    // a caller-supplied key is passed through unchanged
    final Map<String, dynamic> withKey =
        await m3.handle(<String, dynamic>{
      ...input(book, page: 60),
      'idempotency_key': 'caller-key-abc',
    });
    expect(withKey['ok'], true, reason: '$withKey');
    final Map<String, dynamic> again = await m3.handle(<String, dynamic>{
      ...input(book, page: 60),
      'idempotency_key': 'caller-key-abc',
    });
    expect((again['data'] as Map)['saved'], false);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 5 — End-to-End Smoke & Health-Check Probe
  // ---------------------------------------------------------------
  test('Test 5 — End-to-End Smoke & Health-Check Probe', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = await firstCategoryId(m1);
    final String book = await addBook(m1, cat, totalPages: 100);
    final M3ProgressLogger m3 = buildM3(m1);

    expect(await m3.healthCheck(), 'ok');

    // the M3 -> M1 seam works end to end, twice, without doubling
    final Map<String, dynamic> a = await m3.handle(input(book, page: 25));
    final Map<String, dynamic> b = await m3.handle(input(book, page: 25));
    expect(a['ok'], true, reason: '$a');
    expect((a['data'] as Map)['saved'], true);
    expect((b['data'] as Map)['saved'], false);

    final Map<String, dynamic> day =
        await m1.handle(env('read_daily', <String, dynamic>{
      'as_of_date': '2026-10-19',
    }));
    expect((day['data'] as Map)['total_pages_today'], 25);

    await m1.db.close();
  });
}
