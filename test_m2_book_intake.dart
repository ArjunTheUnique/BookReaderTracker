// ============================================================
// MODULE PASSPORT — M2 Book Intake (TEST)
// Version Stamp : v1.0
// Module File   : src/modules/m2_book_intake.dart
// Test File     : tests/test_m2_book_intake.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.1 (Table 2A, row M2)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove M2 honours its IN/OUT socket, its error shapes, its
//   idempotency rule, and the M2 -> M1 seam — using a FAKE file port
//   and a FAKE extractor, so no platform plugin is needed.
// SAFE TO EDIT   : sample titles, page counts, file names below.
// DO NOT TOUCH   : expected field names, error codes, caps.
// 2 AM HINT      : run `flutter test tests/test_m2_book_intake.dart`
//                  from the project root (after build_runner).
// ============================================================

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/modules/m1_library_store.dart';
import '../src/modules/m2_book_intake.dart';

// ---------------------------------------------------------------
// Fakes — the whole point of the ports.
// ---------------------------------------------------------------

class FakeFileAccess implements FileAccess {
  FakeFileAccess({
    List<int>? bytes,
    this.name = 'book.pdf',
    this.deny = false,
    this.copyFails = false,
    this.free = 1 << 40,
  }) : bytes = bytes ?? List<int>.filled(2048, 1);

  final List<int> bytes;
  final String name;
  final bool deny;
  final bool copyFails;
  final int free;
  int copies = 0;

  @override
  Future<PickedFile> pickAndRead() async {
    if (deny) throw FileAccessDenied('user refused');
    return PickedFile(name: name, bytes: bytes);
  }

  @override
  Future<String> copyToAppStorage(String name, List<int> bytes) async {
    if (copyFails) throw StorageCopyFailed('disk full');
    copies++;
    return '/app/storage/$name';
  }

  @override
  Future<int> freeBytes() async => free;
}

class FakeExtractor implements PageExtractor {
  FakeExtractor(this.pages, {this.fail = false});
  final int pages;
  final bool fail;

  @override
  Future<int> pageCount(String name, List<int> bytes) async {
    if (fail) throw ExtractionFailed('cannot parse');
    return pages;
  }
}

// ---------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------

/// Dart is nominally typed, so M1LibraryStore is not automatically a
/// LibraryStorePort. M1 is a frozen module (v1.0.2) that must not be
/// changed by an M2 order, so we adapt it here. This keeps M2 depending
/// on the CONTRACT, not on M1's file.
class M1PortAdapter implements LibraryStorePort {
  M1PortAdapter(this._store);
  final M1LibraryStore _store;

  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope) =>
      _store.handle(envelope);

  @override
  Future<String> healthCheck() => _store.healthCheck();
}

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

M2BookIntake buildM2(
  M1LibraryStore m1, {
  FileAccess? fa,
  PageExtractor? ex,
  int? maxImportMb,
}) =>
    M2BookIntake(
      fileAccess: fa ?? FakeFileAccess(),
      extractor: ex ?? FakeExtractor(42),
      m1: M1PortAdapter(m1),
      maxImportMb: maxImportMb,
      // Zero backoff in tests so the retry path does not slow the run.
      retryBackoffSeconds: const <int>[0, 0],
      parseTimeoutSeconds: 1,
    );

Map<String, dynamic> manualInput({
  required String categoryId,
  String title = 'A Manual Book',
  Object? totalPages = 100,
  String idem = 'k1',
  Object? coverRef,
}) =>
    <String, dynamic>{
      'category_id': categoryId,
      'source': 'manual',
      'file_uri': null,
      'title': title,
      'total_pages': totalPages,
      'cover_ref': coverRef,
      'idempotency_key': idem,
    };

Map<String, dynamic> deviceInput({
  required String categoryId,
  String title = 'A Device Book',
  String fileUri = '/x/novel.pdf',
  String idem = 'k1',
}) =>
    <String, dynamic>{
      'category_id': categoryId,
      'source': 'device_file',
      'file_uri': fileUri,
      'title': title,
      'total_pages': null,
      'cover_ref': null,
      'idempotency_key': idem,
    };

void main() {
  // Each test opens its own in-memory M1; that is intentional and safe.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ---------------------------------------------------------------
  // TEST 1 — Happy-Path Acceptance (2 valid inputs)
  // ---------------------------------------------------------------
  test('Test 1 — Happy-Path Acceptance', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat1 = (await categoryIds(m1)).first;

    // (a) manual book — page count comes from the caller.
    final M2BookIntake m2 = buildM2(m1);
    final Map<String, dynamic> r1 = await m2.handle(manualInput(
        categoryId: cat1, title: 'Manual One', totalPages: 120, idem: 'm-1'));
    expect(r1['ok'], true, reason: '$r1');
    expect((r1['data'] as Map)['total_pages'], 120);
    expect((r1['data'] as Map)['source'], 'manual');

    // (b) device file — page count is EXTRACTED.
    final M2BookIntake m2b = buildM2(
      m1,
      fa: FakeFileAccess(name: 'novel.pdf'),
      ex: FakeExtractor(42),
    );
    final Map<String, dynamic> r2 = await m2b.handle(deviceInput(
        categoryId: cat1, title: 'Device One', fileUri: '/x/novel.pdf', idem: 'd-1'));
    expect(r2['ok'], true, reason: '$r2');
    expect((r2['data'] as Map)['total_pages'], 42);
    expect((r2['data'] as Map)['source'], 'device_file');

    // both landed in M1
    final Map<String, dynamic> cat = await m1.handle(m1env('read_catalog', {}));
    final List<dynamic> cats = (cat['data'] as Map)['categories'] as List<dynamic>;
    expect(((cats.first as Map)['books'] as List).length, 2);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 2 — Boundary & Idempotency Breaker
  // ---------------------------------------------------------------
  test('Test 2 — Boundary & Idempotency Breaker', () async {
    final M1LibraryStore m1 = await freshM1();
    final List<String> cats = await categoryIds(m1);
    final String cat1 = cats[0];
    final String cat2 = cats[1];
    final M2BookIntake m2 = buildM2(m1);

    // fill category 1 with 6 books
    for (int i = 1; i <= 6; i++) {
      final Map<String, dynamic> r = await m2.handle(manualInput(
          categoryId: cat1, title: 'F$i', totalPages: 10, idem: 'f$i'));
      expect(r['ok'], true, reason: '$r');
    }
    // 7th → E3 (passed through from M1)
    final Map<String, dynamic> r7 = await m2.handle(manualInput(
        categoryId: cat1, title: 'F7', totalPages: 10, idem: 'f7'));
    expect((r7['error'] as Map)['code'], 'E3');

    // a file over the cap → E6 (tiny cap so the test stays small)
    final M2BookIntake m2tiny = buildM2(
      m1,
      fa: FakeFileAccess(name: 'big.pdf', bytes: List<int>.filled(1024 * 1024 + 1, 0)),
      maxImportMb: 1,
    );
    final Map<String, dynamic> rBig = await m2tiny.handle(deviceInput(
        categoryId: cat2, fileUri: '/x/big.pdf', idem: 'big-1'));
    expect((rBig['error'] as Map)['code'], 'E6');

    // repeated idempotency_key → added once, not twice
    final Map<String, dynamic> a = await m2.handle(manualInput(
        categoryId: cat2, title: 'Once', totalPages: 33, idem: 'dup-key'));
    final Map<String, dynamic> b = await m2.handle(manualInput(
        categoryId: cat2, title: 'Once', totalPages: 33, idem: 'dup-key'));
    expect(a['ok'], true, reason: '$a');
    expect(b['ok'], true, reason: '$b');
    final Map<String, dynamic> cat = await m1.handle(m1env('read_catalog', {}));
    final List<dynamic> all = (cat['data'] as Map)['categories'] as List<dynamic>;
    final Map c2 = all[1] as Map;
    expect((c2['books'] as List).length, 1, reason: 'duplicate key must not double-add');

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 3 — Explicit Error-Shape Coverage (E1,E2,E3,E4,E6,E7,E8)
  // ---------------------------------------------------------------
  test('Test 3 — Explicit Error-Shape Coverage', () async {
    final M1LibraryStore m1 = await freshM1();
    final List<String> cats = await categoryIds(m1);
    final String cat1 = cats[0];
    final String cat2 = cats[1];
    final M2BookIntake m2 = buildM2(m1);

    // E1 — title too long
    final Map<String, dynamic> e1 = await m2.handle(manualInput(
        categoryId: cat1, title: 'x' * 201, totalPages: 10, idem: 'e1'));
    expect((e1['error'] as Map)['code'], 'E1');

    // E2 — manual total_pages out of range
    final Map<String, dynamic> e2 = await m2.handle(manualInput(
        categoryId: cat1, totalPages: 0, idem: 'e2'));
    expect((e2['error'] as Map)['code'], 'E2');

    // E3 — 7th book in a full category
    for (int i = 1; i <= 6; i++) {
      await m2.handle(manualInput(
          categoryId: cat1, title: 'G$i', totalPages: 10, idem: 'g$i'));
    }
    final Map<String, dynamic> e3 = await m2.handle(manualInput(
        categoryId: cat1, title: 'G7', totalPages: 10, idem: 'g7'));
    expect((e3['error'] as Map)['code'], 'E3');

    // E4 — category does not exist
    final Map<String, dynamic> e4 = await m2.handle(manualInput(
        categoryId: 'ghost', totalPages: 10, idem: 'e4'));
    expect((e4['error'] as Map)['code'], 'E4');

    // E6 — unsupported extension
    final Map<String, dynamic> e6 = await m2.handle(deviceInput(
        categoryId: cat2, fileUri: '/x/notes.txt', idem: 'e6'));
    expect((e6['error'] as Map)['code'], 'E6');

    // E7 — the copy to app storage fails
    final M2BookIntake m2copy = buildM2(m1, fa: FakeFileAccess(copyFails: true));
    final Map<String, dynamic> e7 = await m2copy.handle(deviceInput(
        categoryId: cat2, fileUri: '/x/ok.pdf', idem: 'e7'));
    expect((e7['error'] as Map)['code'], 'E7');

    // E8 — the file port refuses access
    final M2BookIntake m2deny = buildM2(m1, fa: FakeFileAccess(deny: true));
    final Map<String, dynamic> e8 = await m2deny.handle(deviceInput(
        categoryId: cat2, fileUri: '/x/ok.pdf', idem: 'e8'));
    expect((e8['error'] as Map)['code'], 'E8');

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 4 — Registry Seam Contract Test
  // ---------------------------------------------------------------
  test('Test 4 — Registry Seam Contract Test', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat1 = (await categoryIds(m1)).first;
    final M2BookIntake m2 = buildM2(m1);

    final Map<String, dynamic> r = await m2.handle(manualInput(
        categoryId: cat1, title: 'Seam', totalPages: 77, idem: 'seam-1'));
    expect(r['ok'], true, reason: '$r');
    final Map<String, dynamic> data = (r['data'] as Map).cast<String, dynamic>();
    expect(data.keys.toSet(),
        <String>{'book_id', 'category_id', 'total_pages', 'source'});
    expect(data['book_id'], isA<String>());
    expect(data['category_id'], isA<String>());
    expect(data['total_pages'], isA<int>());
    expect(data['source'], isA<String>());
    expect(r['schema_version'], 1);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 5 — End-to-End Smoke & Health-Check Probe
  // ---------------------------------------------------------------
  test('Test 5 — End-to-End Smoke & Health-Check Probe', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat1 = (await categoryIds(m1)).first;
    final M2BookIntake m2 = buildM2(m1);

    expect(await m2.healthCheck(), 'ok');

    // the M2 -> M1 seam works end to end
    final Map<String, dynamic> r = await m2.handle(manualInput(
        categoryId: cat1, title: 'Smoke', totalPages: 15, idem: 'smoke-1'));
    expect(r['ok'], true, reason: '$r');
    final Map<String, dynamic> cat = await m1.handle(m1env('read_catalog', {}));
    final List<dynamic> cats = (cat['data'] as Map)['categories'] as List<dynamic>;
    expect(((cats.first as Map)['books'] as List).length, 1);

    await m1.db.close();
  });
}
