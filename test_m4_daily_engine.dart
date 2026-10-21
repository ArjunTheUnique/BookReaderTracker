// ============================================================
// MODULE PASSPORT — M4 Daily Engine (TEST)
// Version Stamp : v1.0
// Module File   : src/modules/m4_daily_engine.dart
// Test File     : tests/test_m4_daily_engine.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M4)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove M4 honours its IN/OUT socket, its error shapes E1/E2/E4,
//   the timezone-aware "today", the anomaly clamp, and the M4->M1
//   seam — with an injected fake Clock and a real in-memory M1.
// SAFE TO EDIT   : sample dates and page counts below.
// DO NOT TOUCH   : expected field names, error codes, offsets.
// 2 AM HINT      : `flutter test tests/test_m4_daily_engine.dart`
//                  from the project root (after build_runner).
// ============================================================

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/modules/m1_library_store.dart';
import '../src/modules/m4_daily_engine.dart';

// ---------------------------------------------------------------
// Fakes and adapters
// ---------------------------------------------------------------

/// A clock we control, so "today" is deterministic.
class FakeClock implements Clock {
  FakeClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// A stand-in for M1 that returns a fixed response — used to drive the
/// anomaly clamp and the E4 pass-through, which a healthy M1 cannot.
class FakeDailySource implements DailySourcePort {
  FakeDailySource(this.response, {this.healthy = 'ok'});
  final Map<String, dynamic> response;
  final String healthy;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope) async =>
      response;
  @override
  Future<String> healthCheck() async => healthy;
}

/// Dart is nominally typed, so the frozen M1 is adapted to the port.
class M1DailyAdapter implements DailySourcePort {
  M1DailyAdapter(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope) =>
      _store.handle(envelope);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

// ---------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------

Map<String, dynamic> m1env(String op, Map<String, dynamic> payload,
        {String? idem}) =>
    <String, dynamic>{
      'op': op,
      'payload': payload,
      'idempotency_key': idem,
      'schema_version': 1,
    };

Future<M1LibraryStore> freshM1() async {
  final M1LibraryStore store = M1LibraryStore(M1Database(NativeDatabase.memory()));
  await store.seedIfEmpty();
  return store;
}

Future<List<String>> categoryIds(M1LibraryStore m1) async {
  final Map<String, dynamic> r = await m1.handle(m1env('read_catalog', {}));
  final List<dynamic> cats = (r['data'] as Map)['categories'] as List<dynamic>;
  return cats.map((dynamic c) => (c as Map)['category_id'] as String).toList();
}

int _seq = 0;
Future<String> addBook(M1LibraryStore m1, String categoryId,
    {int totalPages = 100}) async {
  final String bookId = 'book-${++_seq}';
  final Map<String, dynamic> r = await m1.handle(m1env(
    'add_book',
    <String, dynamic>{
      'book_id': bookId,
      'category_id': categoryId,
      'title': 'Book $bookId',
      'total_pages': totalPages,
      'source': 'manual',
      'file_path': null,
      'cover_ref': null,
    },
    idem: 'ab-$bookId',
  ));
  expect(r['ok'], true, reason: '$r');
  return bookId;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ---------------------------------------------------------------
  // TEST 1 — Happy-Path Acceptance
  // ---------------------------------------------------------------
  test('Test 1 — Happy-Path Acceptance', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = (await categoryIds(m1)).first;
    final String bookA = await addBook(m1, cat, totalPages: 100);
    final String bookB = await addBook(m1, cat, totalPages: 50);

    // two valid inputs on the same day: 50/100 and 25/50
    final Map<String, dynamic> upA = await m1.handle(m1env(
      'update_progress',
      <String, dynamic>{'book_id': bookA, 'current_page': 50, 'read_on': '2026-10-19'},
      idem: 'pA',
    ));
    expect(upA['ok'], true, reason: '$upA');
    final Map<String, dynamic> upB = await m1.handle(m1env(
      'update_progress',
      <String, dynamic>{'book_id': bookB, 'current_page': 25, 'read_on': '2026-10-19'},
      idem: 'pB',
    ));
    expect(upB['ok'], true, reason: '$upB');

    final M4DailyEngine m4 = M4DailyEngine(
      m1: M1DailyAdapter(m1),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );
    final Map<String, dynamic> r = await m4.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': 330, // IST
    });
    expect(r['ok'], true, reason: '$r');
    final Map<String, dynamic> data = (r['data'] as Map).cast<String, dynamic>();
    expect(data['total_pages_today'], 75); // 50 + 25
    final List<Map<String, dynamic>> pb = (data['per_book'] as List)
        .map((dynamic e) => (e as Map).cast<String, dynamic>())
        .toList();
    expect(pb.length, 2);
    final Map<String, dynamic> a =
        pb.firstWhere((Map<String, dynamic> e) => e['book_id'] == bookA);
    final Map<String, dynamic> b =
        pb.firstWhere((Map<String, dynamic> e) => e['book_id'] == bookB);
    expect(a['pages_today'], 50);
    expect(a['pct_today'], 50.0);
    expect(b['pages_today'], 25);
    expect(b['pct_today'], 50.0);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 2 — Boundary & Anomaly Breaker
  // ---------------------------------------------------------------
  test('Test 2 — Boundary & Anomaly Breaker', () async {
    final M1LibraryStore m1 = await freshM1();
    final M4DailyEngine m4 = M4DailyEngine(
      m1: M1DailyAdapter(m1),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );

    // (a) an empty day is a SUCCESS with zeros, not an error
    final Map<String, dynamic> empty = await m4.handle(<String, dynamic>{
      'as_of_date': '2026-01-01',
      'timezone_offset_min': 0,
    });
    expect(empty['ok'], true, reason: '$empty');
    final Map<String, dynamic> ed = (empty['data'] as Map).cast<String, dynamic>();
    expect(ed['total_pages_today'], 0);
    expect(ed['per_book'], isEmpty);

    // (b) a backwards clock jump produces a negative -> clamped to 0
    final M4DailyEngine m4neg = M4DailyEngine(
      m1: FakeDailySource(<String, dynamic>{
        'ok': true,
        'data': <String, dynamic>{
          'date': '2026-10-19',
          'total_pages_today': -5,
          'per_book': <dynamic>[
            <String, dynamic>{
              'book_id': 'b1',
              'pages_today': -5,
              'pct_today': -10.0,
            },
          ],
        },
        'schema_version': 1,
      }),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );
    final Map<String, dynamic> neg = await m4neg.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': 0,
    });
    expect(neg['ok'], true, reason: '$neg');
    final Map<String, dynamic> nd = (neg['data'] as Map).cast<String, dynamic>();
    expect(nd['total_pages_today'], 0);
    final Map<String, dynamic> npb =
        ((nd['per_book'] as List).first as Map).cast<String, dynamic>();
    expect(npb['pages_today'], 0);
    expect(npb['pct_today'], 0.0);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 3 — Explicit Error-Shape Coverage (E1, E2, E4)
  // ---------------------------------------------------------------
  test('Test 3 — Explicit Error-Shape Coverage', () async {
    final M1LibraryStore m1 = await freshM1();
    final M4DailyEngine m4 = M4DailyEngine(
      m1: M1DailyAdapter(m1),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );

    // E1 — invalid date
    final Map<String, dynamic> e1 = await m4.handle(<String, dynamic>{
      'as_of_date': '2026-13-99',
      'timezone_offset_min': 0,
    });
    expect((e1['error'] as Map)['code'], 'E1');

    // E2 — offset out of range
    final Map<String, dynamic> e2 = await m4.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': 900,
    });
    expect((e2['error'] as Map)['code'], 'E2');

    // E4 — a required referenced entity is missing (passed through from M1)
    final M4DailyEngine m4missing = M4DailyEngine(
      m1: FakeDailySource(<String, dynamic>{
        'ok': false,
        'error': <String, dynamic>{
          'code': 'E4',
          'message': 'a required entity is missing',
        },
      }),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );
    final Map<String, dynamic> e4 = await m4missing.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': 0,
    });
    expect((e4['error'] as Map)['code'], 'E4');

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 4 — Registry Seam Contract Test
  // ---------------------------------------------------------------
  test('Test 4 — Registry Seam Contract Test', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = (await categoryIds(m1)).first;
    final String bookId = await addBook(m1, cat, totalPages: 100);
    await m1.handle(m1env('update_progress',
        <String, dynamic>{'book_id': bookId, 'current_page': 20, 'read_on': '2026-10-19'},
        idem: 'p4'));

    final M4DailyEngine m4 = M4DailyEngine(
      m1: M1DailyAdapter(m1),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 12)),
    );
    final Map<String, dynamic> r = await m4.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': 330,
    });
    expect(r['ok'], true, reason: '$r');
    final Map<String, dynamic> data = (r['data'] as Map).cast<String, dynamic>();
    expect(data.keys.toSet(),
        <String>{'date', 'total_pages_today', 'per_book'});
    expect(data['date'], isA<String>());
    expect(data['total_pages_today'], isA<int>());
    expect(data['per_book'], isA<List<dynamic>>());
    final Map<String, dynamic> entry =
        ((data['per_book'] as List).first as Map).cast<String, dynamic>();
    expect(entry.keys.toSet(),
        <String>{'book_id', 'pages_today', 'pct_today'});
    expect(entry['book_id'], isA<String>());
    expect(entry['pages_today'], isA<int>());
    expect(entry['pct_today'], isA<double>());
    expect(r['schema_version'], 1);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 5 — End-to-End Smoke & Health-Check Probe
  // ---------------------------------------------------------------
  test('Test 5 — End-to-End Smoke & Health-Check Probe', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = (await categoryIds(m1)).first;
    final String bookId = await addBook(m1, cat, totalPages: 200);

    final M4DailyEngine m4 = M4DailyEngine(
      m1: M1DailyAdapter(m1),
      clock: FakeClock(DateTime.utc(2026, 10, 19, 6)),
    );

    expect(await m4.healthCheck(), 'ok');

    // the M4 -> M1 seam works end to end
    await m1.handle(m1env('update_progress',
        <String, dynamic>{'book_id': bookId, 'current_page': 40, 'read_on': '2026-10-19'},
        idem: 'p5'));
    final Map<String, dynamic> r = await m4.handle(<String, dynamic>{
      'as_of_date': '2026-10-19',
      'timezone_offset_min': -300, // EST
    });
    expect(r['ok'], true, reason: '$r');
    expect((r['data'] as Map)['total_pages_today'], 40);

    await m1.db.close();
  });
}
