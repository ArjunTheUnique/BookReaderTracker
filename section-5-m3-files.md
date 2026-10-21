# SECTION 5 — FULL MODULE AND TEST CONTENTS

## `src/modules/m3_progress_logger.dart`

```dart
// ============================================================
// MODULE PASSPORT — M3 Progress Logger
// Version Stamp : v1.0
// Module File   : src/modules/m3_progress_logger.dart
// Test File     : tests/test_m3_progress_logger.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M3)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Record how far a user has read — safely against double-taps.
//   M3 validates the request, settles on one stable idempotency key,
//   and forwards the write to M1. It never touches the database and
//   never does daily maths.
//
// MACHINE SOCKET CONTRACT SUMMARY
//   INPUT  : { book_id, current_page, read_on, idempotency_key }
//   OUTPUT success : { ok:true, data:{book_id, current_page, pct_read,
//                      saved}, schema_version:1 }
//   OUTPUT failure : { ok:false, error:{code, message, field?} }
//   ERROR SHAPES : E1 INVALID_INPUT · E2 OUT_OF_RANGE ·
//                  E4 NOT_FOUND · E5 DUPLICATE
//
// CONTROL PATH SUMMARY (the C-switch inside this file)
//   C4 save progress — validate the page range and the date, settle the
//      idempotency key, and forward to M1. A repeated key is NOT an
//      error: it comes back { ok:true, saved:false }.
//
// DATA PATH SUMMARY (the D-pipe inside this file)
//   D2 progress pipe — the write itself is M1's `update_progress`. M3
//      only calls it. M3 never touches `daily_summary` (that is M4's D4).
//
// SCOPE NOTE
//   M3 does NOT implement the "backward progress -> confirm" prompt
//   (S4); it only rejects out-of-range values (with M1's E2). Any
//   confirmation UX belongs to the app shell.
//
// SAFE TO EDIT BY HAND GUIDE
//   Everything under ZONE 1: the log label, and the private
//   idempotency-key derivation detail (keep it STABLE — the same
//   logical save must always yield the same key).
//
// DO NOT TOUCH WARNING
//   The IN/OUT contract field names and types, the error codes E1..E9,
//   the delegation to M1, and the rule that M3 does NO daily maths.
//
// 2 AM TROUBLESHOOTING HINT
//   On any failure this module returns
//   { ok:false, error:{ code:"E*", message:"...", field? } } and prints
//   "[M3] <CODE>: <detail>". E4 means the book id does not exist; E2
//   means the page is outside the book; E5 means the store reported a
//   duplicate. A SECOND identical save is NOT an error — it returns
//   ok with saved:false.
// ============================================================

import 'dart:async';

// ============================================================
// === ZONE 1: SAFE TO EDIT CONFIGURATION & RULES ===
// ============================================================

/// The contract version this module speaks.
const int kSchemaVersion = 1;

/// Log verbosity label. M3 owns exactly one config value.
const String kLogLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');

// ============================================================
// === ZONE 2: BOUNDARY VALIDATION & MACHINE SOCKET CONTRACT ===
// ============================================================

/// The injected clock. M3 never calls `DateTime.now()` itself, so tests
/// are deterministic (the same discipline as M2's ports, ADR-015).
abstract class Clock {
  DateTime now();
}

/// The slice of M1 that M3 writes through. M3 knows nothing else about
/// M1 — no tables, no SQL, no drift types.
abstract class ProgressStorePort {
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope);
  Future<String> healthCheck();
}

/// The Progress Logger.
class M3ProgressLogger {
  M3ProgressLogger({required this.store, required this.clock});

  final ProgressStorePort store;
  final Clock clock;

  static const Set<String> _allowedKeys = <String>{
    'book_id',
    'current_page',
    'read_on',
    'idempotency_key',
  };
  static const Set<String> _requiredKeys = <String>{
    'book_id',
    'current_page',
    'read_on',
  };

  /// THE socket.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input) async {
    // ---- boundary validation, in the order the order lays down ----
    for (final String k in input.keys) {
      if (!_allowedKeys.contains(k)) {
        return _fail('E1', 'Unexpected field "$k".', k);
      }
    }
    for (final String k in _requiredKeys) {
      if (!input.containsKey(k)) {
        return _fail('E1', 'Missing required field "$k".', k);
      }
    }

    final Object? bookId = input['book_id'];
    if (bookId is! String || bookId.isEmpty) {
      return _fail('E1', 'book_id must be a non-empty string.', 'book_id');
    }

    final Object? page = input['current_page'];
    if (page is! int) {
      return _fail('E1', 'current_page must be an integer.', 'current_page');
    }

    final Object? readOn = input['read_on'];
    if (readOn is! String || !isIsoDate(readOn)) {
      return _fail('E1', 'read_on must match YYYY-MM-DD.', 'read_on');
    }
    if (_isFuture(readOn)) {
      return _fail('E1', 'read_on is in the future.', 'read_on');
    }

    // ---- settle the idempotency key (M3's core responsibility) ----
    // A caller-supplied key is passed through UNCHANGED. If the caller
    // supplies none, M3 derives a STABLE key from the logical save, so
    // two identical saves collide and M1's ledger makes the second a
    // silent no-op. A key that is present but empty is malformed (E1).
    final Object? suppliedKey = input['idempotency_key'];
    final String idemKey;
    if (suppliedKey == null) {
      idemKey = _deriveKey(bookId, readOn, page);
    } else if (suppliedKey is! String || suppliedKey.isEmpty) {
      return _fail('E1', 'idempotency_key must be a non-empty string.',
          'idempotency_key');
    } else {
      idemKey = suppliedKey;
    }

    // ---- forward the write to M1 (D2) ----
    Map<String, dynamic> r;
    try {
      r = await store.handle(<String, dynamic>{
        'op': 'update_progress',
        'payload': <String, dynamic>{
          'book_id': bookId,
          'current_page': page,
          'read_on': readOn,
        },
        'idempotency_key': idemKey,
        'schema_version': kSchemaVersion,
      });
    } catch (e) {
      return _fail('E7', 'The progress write failed: $e');
    }

    // E1/E2/E4/E5 (and any storage E7) are returned to the caller
    // UNCHANGED — M3 never re-shapes M1's error.
    if (r['ok'] != true) return r;

    final Map<String, dynamic> d = (r['data'] as Map).cast<String, dynamic>();
    return _ok(<String, dynamic>{
      'book_id': d['book_id'],
      'current_page': d['current_page'],
      'pct_read': d['pct_read'],
      'saved': d['saved'],
    });
  }

  // ============================================================
  // === ZONE 3: CONTROL PATH FUNCTIONS (THE SWITCHES) ===
  // ============================================================

  /// C4 helper: is `YYYY-MM-DD` a real calendar date?
  static bool isIsoDate(String s) {
    if (s.length != 10 || s[4] != '-' || s[7] != '-') return false;
    final int? y = int.tryParse(s.substring(0, 4));
    final int? m = int.tryParse(s.substring(5, 7));
    final int? d = int.tryParse(s.substring(8, 10));
    if (y == null || m == null || d == null) return false;
    if (m < 1 || m > 12 || d < 1 || d > 31) return false;
    final DateTime probe = DateTime.utc(y, m, d);
    return probe.year == y && probe.month == m && probe.day == d;
  }

  /// C4 helper: a reading date later than "today" is not a real save.
  /// "Today" comes from the injected Clock, never from DateTime.now().
  bool _isFuture(String readOn) {
    final DateTime now = clock.now().toUtc();
    final String today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return readOn.compareTo(today) > 0;
  }

  // ============================================================
  // === ZONE 4: DATA PATH, FAILURE-SHIELD & HEALTH-PROBE (PIPES) ===
  // ============================================================

  /// D2 helper: the STABLE derived key. Two identical logical saves must
  /// always produce this same string. Keep it deterministic.
  String _deriveKey(String bookId, String readOn, int currentPage) {
    final String seed = '$bookId|$readOn|$currentPage';
    return 'm3:${_fnv1a32(seed).toRadixString(16).padLeft(8, '0')}';
  }

  static int _fnv1a32(String s) {
    int h = 0x811c9dc5;
    for (final int unit in s.codeUnits) {
      h ^= (unit & 0xFF);
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Health probe. Confirms the M1 seam answers.
  Future<String> healthCheck() async {
    try {
      return await store.healthCheck();
    } catch (e) {
      return 'degraded: $e';
    }
  }

  Map<String, dynamic> _ok(Map<String, dynamic> data) => <String, dynamic>{
        'ok': true,
        'data': data,
        'schema_version': kSchemaVersion,
      };

  Map<String, dynamic> _fail(String code, String message, [String? field]) {
    // ignore: avoid_print
    print('[M3] $code: $message');
    return <String, dynamic>{
      'ok': false,
      'error': <String, dynamic>{
        'code': code,
        'message': message,
        if (field != null) 'field': field,
      },
    };
  }
}
```

## `tests/test_m3_progress_logger.dart`

```dart
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
```
