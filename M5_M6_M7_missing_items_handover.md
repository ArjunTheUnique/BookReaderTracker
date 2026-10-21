# M5 / M6 / M7 — the six missing items (handover to the Architect)

These are exactly the six items requested in `M567_MISSING_ITEMS_REQUEST.md`:
the three test files and the three `.env.example` blocks.

Nothing here is new work — the modules themselves are unchanged. These files were part of
the original M5/M6/M7 delivery; they simply were not forwarded with the code. The three
suites were run together with the whole stack (M1–M7) and all passed 5/5 each; the verbatim
`flutter test` output is in `M5_M6_M7_v1.0_receipt.txt`.

---

## 1. Test files

### 1a. `tests/test_m5_widget_bridge.dart`

```dart
// ============================================================
// MODULE PASSPORT — M5 Widget Bridge (TEST)
// Version Stamp : v1.0
// Module File   : src/modules/m5_widget_bridge.dart
// Test File     : tests/test_m5_widget_bridge.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M5)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove M5 honours its IN/OUT socket, its error shapes E1/E7/E8,
//   and the deep-link route — using a FAKE WidgetHost (no plugin).
// SAFE TO EDIT   : sample page counts and ids below.
// DO NOT TOUCH   : expected field names, error codes.
// 2 AM HINT      : `flutter test tests/test_m5_widget_bridge.dart`.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import '../src/modules/m5_widget_bridge.dart';

/// A fake widget host that records what was pushed, and can be told to
/// fail the way the real host would.
class FakeWidgetHost implements WidgetHost {
  FakeWidgetHost({this.storageFails = false, this.permissionDenied = false});

  final bool storageFails;
  final bool permissionDenied;
  Map<String, dynamic>? lastPayload;
  int writes = 0;

  @override
  Future<void> writePayload(Map<String, dynamic> payload) async {
    if (permissionDenied) throw WidgetHostPermissionDenied('refused');
    if (storageFails) throw WidgetHostStorageError('shared store unwritable');
    lastPayload = payload;
    writes++;
  }

  @override
  Future<String> healthCheck() async => 'ok';
}

Map<String, dynamic> pushInput({
  Object goal = 20,
  Object total = 30,
  List<dynamic>? pcts,
}) =>
    <String, dynamic>{
      'goal_pages': goal,
      'total_pages_today': total,
      'per_book_pct': pcts ??
          <dynamic>[
            <String, dynamic>{'book_id': 'a', 'pct': 50.0},
          ],
    };

void main() {
  // ---------------------------------------------------------------
  // TEST 1 — Happy-Path Acceptance (2 valid inputs)
  // ---------------------------------------------------------------
  test('Test 1 — Happy-Path Acceptance', () async {
    final FakeWidgetHost host = FakeWidgetHost();
    final M5WidgetBridge m5 = M5WidgetBridge(host: host);

    // (a) a push with two books
    final Map<String, dynamic> r1 = await m5.push(pushInput(
      goal: 20,
      total: 30,
      pcts: <dynamic>[
        <String, dynamic>{'book_id': 'a', 'pct': 50.0},
        <String, dynamic>{'book_id': 'b', 'pct': 25.0},
      ],
    ));
    expect(r1['ok'], true, reason: '$r1');
    expect((r1['data'] as Map)['pushed_at'], isA<String>());
    expect(host.lastPayload!['goal_pages'], 20);
    expect((host.lastPayload!['per_book_pct'] as List).length, 2);

    // (b) an empty-day push is valid too
    final Map<String, dynamic> r2 =
        await m5.push(pushInput(total: 0, pcts: <dynamic>[]));
    expect(r2['ok'], true, reason: '$r2');
  });

  // ---------------------------------------------------------------
  // TEST 2 — Boundary & Idempotency Breaker
  // ---------------------------------------------------------------
  test('Test 2 — Boundary & Idempotency Breaker', () async {
    final FakeWidgetHost host = FakeWidgetHost();
    final M5WidgetBridge m5 = M5WidgetBridge(host: host);

    // malformed payload -> E1
    final Map<String, dynamic> bad = await m5.push(pushInput(goal: -1));
    expect((bad['error'] as Map)['code'], 'E1');

    // a repeated push of the same payload is harmless
    final Map<String, dynamic> p = pushInput();
    final Map<String, dynamic> a = await m5.push(p);
    final Map<String, dynamic> b = await m5.push(p);
    expect(a['ok'], true, reason: '$a');
    expect(b['ok'], true, reason: '$b');
    expect(host.writes, 2);
  });

  // ---------------------------------------------------------------
  // TEST 3 — Explicit Error-Shape Coverage (E1, E7, E8)
  // ---------------------------------------------------------------
  test('Test 3 — Explicit Error-Shape Coverage', () async {
    final M5WidgetBridge m5 = M5WidgetBridge(host: FakeWidgetHost());

    // E1 — bad target_type
    final Map<String, dynamic> e1 = await m5.tap(<String, dynamic>{
      'target_type': 'shelf',
      'target_id': 'x',
    });
    expect((e1['error'] as Map)['code'], 'E1');

    // E7 — the host cannot write the shared store
    final M5WidgetBridge m7 =
        M5WidgetBridge(host: FakeWidgetHost(storageFails: true));
    final Map<String, dynamic> e7 = await m7.push(pushInput());
    expect((e7['error'] as Map)['code'], 'E7');

    // E8 — the OS refuses widget permission
    final M5WidgetBridge m8 =
        M5WidgetBridge(host: FakeWidgetHost(permissionDenied: true));
    final Map<String, dynamic> e8 = await m8.push(pushInput());
    expect((e8['error'] as Map)['code'], 'E8');
  });

  // ---------------------------------------------------------------
  // TEST 4 — Registry Seam Contract Test
  // ---------------------------------------------------------------
  test('Test 4 — Registry Seam Contract Test', () async {
    final M5WidgetBridge m5 = M5WidgetBridge(host: FakeWidgetHost());

    final Map<String, dynamic> push = await m5.push(pushInput());
    expect(push['ok'], true, reason: '$push');
    expect((push['data'] as Map).keys.toSet(), <String>{'pushed_at'});
    expect((push['data'] as Map)['pushed_at'], isA<String>());
    expect(push['schema_version'], 1);

    final Map<String, dynamic> tap = await m5.tap(<String, dynamic>{
      'target_type': 'book',
      'target_id': 'book-1',
    });
    expect(tap['ok'], true, reason: '$tap');
    expect((tap['data'] as Map).keys.toSet(), <String>{'route'});
    final String route = (tap['data'] as Map)['route'] as String;
    expect(route.isNotEmpty, true);
    expect(route, 'shelf://book/book-1');
    expect(tap['schema_version'], 1);
  });

  // ---------------------------------------------------------------
  // TEST 5 — End-to-End Smoke & Health-Check Probe
  // ---------------------------------------------------------------
  test('Test 5 — End-to-End Smoke & Health-Check Probe', () async {
    final FakeWidgetHost host = FakeWidgetHost();
    final M5WidgetBridge m5 = M5WidgetBridge(host: host);

    expect(await m5.healthCheck(), 'ok');

    final Map<String, dynamic> push = await m5.push(pushInput());
    expect(push['ok'], true, reason: '$push');
    expect(host.lastPayload, isNotNull);

    final Map<String, dynamic> tap = await m5.tap(<String, dynamic>{
      'target_type': 'category',
      'target_id': 'cat-1',
    });
    expect(tap['ok'], true, reason: '$tap');
    expect((tap['data'] as Map)['route'], 'shelf://category/cat-1');
  });
}
```

### 1b. `tests/test_m6_backup_vault.dart`

```dart
// ============================================================
// MODULE PASSPORT — M6 Backup Vault (TEST)
// Version Stamp : v1.0
// Module File   : src/modules/m6_backup_vault.dart
// Test File     : tests/test_m6_backup_vault.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M6)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Prove M6 honours its IN/OUT socket, its error shapes E1/E7/E9,
//   and — most importantly — that a FAILED restore leaves the live
//   data untouched. Uses fake FileVault + Cipher, and a real M1 for
//   the snapshot side.
// 2 AM HINT : `flutter test tests/test_m6_backup_vault.dart`.
// ============================================================

import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../src/modules/m1_library_store.dart';
import '../src/modules/m6_backup_vault.dart';

// ---------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------

class FakeFileVault implements FileVault {
  final Map<String, List<int>> store = <String, List<int>>{};
  bool readFails = false;
  bool writeFails = false;

  @override
  Future<void> write(String uri, List<int> bytes) async {
    if (writeFails) throw VaultIoError('write failed');
    store[uri] = List<int>.from(bytes);
  }

  @override
  Future<List<int>> read(String uri) async {
    if (readFails) throw VaultIoError('read failed');
    final List<int>? b = store[uri];
    if (b == null) throw VaultIoError('file missing');
    return b;
  }
}

/// A reversible stand-in for AES-256-GCM: a passphrase magic prefix plus
/// an XOR body. A wrong passphrase fails the magic check, like GCM's tag.
class FakeCipher implements Cipher {
  List<int> _magic(String pass) => utf8.encode('RTBK|$pass|');

  @override
  Future<List<int>> encrypt(List<int> plain, String passphrase) async {
    final List<int> key = passphrase.codeUnits;
    final List<int> out = <int>[..._magic(passphrase)];
    for (int i = 0; i < plain.length; i++) {
      out.add((plain[i] ^ key[i % key.length]) & 0xFF);
    }
    return out;
  }

  @override
  Future<List<int>> decrypt(List<int> cipher, String passphrase) async {
    final List<int> magic = _magic(passphrase);
    if (cipher.length < magic.length) throw CipherError('short');
    for (int i = 0; i < magic.length; i++) {
      if (cipher[i] != magic[i]) throw CipherError('wrong passphrase');
    }
    final List<int> body = cipher.sublist(magic.length);
    final List<int> key = passphrase.codeUnits;
    return <int>[
      for (int i = 0; i < body.length; i++) (body[i] ^ key[i % key.length]) & 0xFF,
    ];
  }
}

/// A simple in-memory library seam.
class FakeLibrary implements LibraryVaultPort {
  FakeLibrary(this.snap);
  Map<String, dynamic> snap;
  bool replaceFails = false;
  int replaces = 0;

  @override
  Future<Map<String, dynamic>> snapshot() async => snap;

  @override
  Future<void> atomicReplace(Map<String, dynamic> s) async {
    if (replaceFails) throw VaultIoError('replace failed');
    snap = s;
    replaces++;
  }

  @override
  Future<String> healthCheck() async => 'ok';
}

/// The M1 seam. Snapshot reads the REAL M1 catalog; the replace is held
/// in memory because M1 v1.0.2 exposes no restore API (see Section 5, F1).
class M1BackedVault implements LibraryVaultPort {
  M1BackedVault(this._m1);
  final M1LibraryStore _m1;
  Map<String, dynamic>? lastReplaced;

  @override
  Future<Map<String, dynamic>> snapshot() async {
    final Map<String, dynamic> r = await _m1.handle(<String, dynamic>{
      'op': 'read_catalog',
      'payload': <String, dynamic>{},
      'idempotency_key': null,
      'schema_version': 1,
    });
    return (r['data'] as Map).cast<String, dynamic>();
  }

  @override
  Future<void> atomicReplace(Map<String, dynamic> s) async {
    lastReplaced = s;
  }

  @override
  Future<String> healthCheck() => _m1.healthCheck();
}

// ---------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------

Future<M1LibraryStore> freshM1() async {
  final M1LibraryStore s = M1LibraryStore(M1Database(NativeDatabase.memory()));
  await s.seedIfEmpty();
  return s;
}

Future<String> firstCategoryId(M1LibraryStore m1) async {
  final Map<String, dynamic> r = await m1.handle(<String, dynamic>{
    'op': 'read_catalog',
    'payload': <String, dynamic>{},
    'idempotency_key': null,
    'schema_version': 1,
  });
  return ((r['data'] as Map)['categories'] as List).first['category_id'] as String;
}

int _seq = 0;
Future<void> addBook(M1LibraryStore m1, String cat) async {
  final String id = 'bk-${++_seq}';
  final Map<String, dynamic> r = await m1.handle(<String, dynamic>{
    'op': 'add_book',
    'payload': <String, dynamic>{
      'book_id': id,
      'category_id': cat,
      'title': 'Book $id',
      'total_pages': 100,
      'source': 'manual',
      'file_path': null,
      'cover_ref': null,
    },
    'idempotency_key': 'ab-$id',
    'schema_version': 1,
  });
  expect(r['ok'], true, reason: '$r');
}

const String kGoodPass = 'correct-horse';
const String kUri = '/vault/library.rtbk';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ---------------------------------------------------------------
  // TEST 1 — Happy-Path Acceptance
  // ---------------------------------------------------------------
  test('Test 1 — Happy-Path Acceptance', () async {
    final M1LibraryStore m1 = await freshM1();
    await addBook(m1, await firstCategoryId(m1));

    final FakeFileVault files = FakeFileVault();
    final M6BackupVault m6 = M6BackupVault(
      files: files,
      cipher: FakeCipher(),
      library: M1BackedVault(m1),
    );

    // export
    final Map<String, dynamic> ex = await m6.export(<String, dynamic>{
      'destination_uri': kUri,
      'passphrase': kGoodPass,
    });
    expect(ex['ok'], true, reason: '$ex');
    expect((ex['data'] as Map)['bytes'], isA<int>());
    expect(files.store.containsKey(kUri), true);
    final String checksum = (ex['data'] as Map)['checksum'] as String;
    expect(checksum.isNotEmpty, true);

    // restore into a fresh target
    final FakeLibrary target = FakeLibrary(<String, dynamic>{'categories': <dynamic>[]});
    final M6BackupVault m6b = M6BackupVault(
      files: files,
      cipher: FakeCipher(),
      library: target,
    );
    final Map<String, dynamic> rs = await m6b.restore(<String, dynamic>{
      'source_uri': kUri,
      'passphrase': kGoodPass,
    });
    expect(rs['ok'], true, reason: '$rs');
    expect((rs['data'] as Map)['checksum'], checksum);
    // the restored snapshot matches what M1 held
    final List<dynamic> restoredCats =
        (target.snap['categories'] as List<dynamic>);
    expect(restoredCats.length, 6);
    final int books = restoredCats
        .fold<int>(0, (int a, dynamic c) => a + ((c as Map)['books'] as List).length);
    expect(books, 1);

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 2 — Boundary & Idempotency Breaker
  // ---------------------------------------------------------------
  test('Test 2 — Boundary & Idempotency Breaker', () async {
    final M1LibraryStore m1 = await freshM1();
    await addBook(m1, await firstCategoryId(m1));

    final FakeFileVault files = FakeFileVault();
    final FakeLibrary target = FakeLibrary(<String, dynamic>{'marker': 'LIVE-DATA'});
    final M6BackupVault m6 = M6BackupVault(
      files: files,
      cipher: FakeCipher(),
      library: M1BackedVault(m1),
    );
    await m6.export(<String, dynamic>{'destination_uri': kUri, 'passphrase': kGoodPass});

    final M6BackupVault reader = M6BackupVault(
      files: files,
      cipher: FakeCipher(),
      library: target,
    );

    // (a) wrong passphrase -> E9, live data untouched
    final Map<String, dynamic> wrong = await reader.restore(
        <String, dynamic>{'source_uri': kUri, 'passphrase': 'wrong-passphrase'});
    expect((wrong['error'] as Map)['code'], 'E9');
    expect(target.snap['marker'], 'LIVE-DATA');

    // (b) a corrupted file -> E9, live data still untouched
    files.store[kUri]![files.store[kUri]!.length - 1] ^= 0xFF;
    final Map<String, dynamic> corrupt = await reader.restore(
        <String, dynamic>{'source_uri': kUri, 'passphrase': kGoodPass});
    expect((corrupt['error'] as Map)['code'], 'E9');
    expect(target.snap['marker'], 'LIVE-DATA');

    await m1.db.close();
  });

  // ---------------------------------------------------------------
  // TEST 3 — Explicit Error-Shape Coverage (E1, E7, E9)
  // ---------------------------------------------------------------
  test('Test 3 — Explicit Error-Shape Coverage', () async {
    final FakeFileVault files = FakeFileVault();
    final FakeLibrary lib = FakeLibrary(<String, dynamic>{'x': 1});
    final M6BackupVault m6 =
        M6BackupVault(files: files, cipher: FakeCipher(), library: lib);

    // E1 — empty uri
    final Map<String, dynamic> e1 = await m6.export(
        <String, dynamic>{'destination_uri': '', 'passphrase': kGoodPass});
    expect((e1['error'] as Map)['code'], 'E1');

    // E1 — weak passphrase
    final Map<String, dynamic> e1b = await m6.export(
        <String, dynamic>{'destination_uri': kUri, 'passphrase': 'short'});
    expect((e1b['error'] as Map)['code'], 'E1');

    // E7 — the file cannot be written
    files.writeFails = true;
    final Map<String, dynamic> e7 = await m6.export(
        <String, dynamic>{'destination_uri': kUri, 'passphrase': kGoodPass});
    expect((e7['error'] as Map)['code'], 'E7');
    files.writeFails = false;

    // E9 — unknown schema version in the file
    files.store[kUri] = utf8.encode('{"schema_version":999,"checksum":"x","payload":""}');
    final Map<String, dynamic> e9 = await m6.restore(
        <String, dynamic>{'source_uri': kUri, 'passphrase': kGoodPass});
    expect((e9['error'] as Map)['code'], 'E9');
  });

  // ---------------------------------------------------------------
  // TEST 4 — Registry Seam Contract Test
  // ---------------------------------------------------------------
  test('Test 4 — Registry Seam Contract Test', () async {
    final FakeFileVault files = FakeFileVault();
    final FakeLibrary lib = FakeLibrary(<String, dynamic>{'x': 1});
    final M6BackupVault m6 =
        M6BackupVault(files: files, cipher: FakeCipher(), library: lib);

    final Map<String, dynamic> ex = await m6.export(
        <String, dynamic>{'destination_uri': kUri, 'passphrase': kGoodPass});
    expect(ex['ok'], true, reason: '$ex');
    final Map<String, dynamic> data = (ex['data'] as Map).cast<String, dynamic>();
    expect(data.keys.toSet(), <String>{'bytes', 'schema_version', 'checksum'});
    expect(data['bytes'], isA<int>());
    expect(data['schema_version'], isA<int>());
    expect(data['checksum'], isA<String>());
    expect(ex['schema_version'], 1);
  });

  // ---------------------------------------------------------------
  // TEST 5 — End-to-End Smoke & Health-Check Probe
  // ---------------------------------------------------------------
  test('Test 5 — End-to-End Smoke & Health-Check Probe', () async {
    final M1LibraryStore m1 = await freshM1();
    final String cat = await firstCategoryId(m1);
    await addBook(m1, cat);
    await addBook(m1, cat);

    final FakeFileVault files = FakeFileVault();
    final M1BackedVault source = M1BackedVault(m1);
    final M6BackupVault m6 =
        M6BackupVault(files: files, cipher: FakeCipher(), library: source);

    expect(await m6.healthCheck(), 'ok');

    // full export -> restore round-trip
    final Map<String, dynamic> ex = await m6.export(
        <String, dynamic>{'destination_uri': kUri, 'passphrase': kGoodPass});
    expect(ex['ok'], true, reason: '$ex');

    final FakeLibrary target = FakeLibrary(<String, dynamic>{'categories': <dynamic>[]});
    final M6BackupVault m6b =
        M6BackupVault(files: files, cipher: FakeCipher(), library: target);
    final Map<String, dynamic> rs = await m6b.restore(
        <String, dynamic>{'source_uri': kUri, 'passphrase': kGoodPass});
    expect(rs['ok'], true, reason: '$rs');

    final List<dynamic> cats = target.snap['categories'] as List<dynamic>;
    final int books =
        cats.fold<int>(0, (int a, dynamic c) => a + ((c as Map)['books'] as List).length);
    expect(books, 2);

    await m1.db.close();
  });
}
```

### 1c. `tests/test_m7_grid_presenter.dart`

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

---

## 2. `.env.example` blocks

### 2a. M5 Widget Bridge — `.env.example`

# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M5 Widget Bridge
# Version Stamp : v1.0
# ------------------------------------------------------------
# These are NON-SECRET tunables only. No credentials, tokens or
# keys exist in this module, and none may be introduced.
# ============================================================

# How often the widget is asked to refresh, in minutes.
WIDGET_REFRESH_MIN=30

# Whether the widget may show book titles (privacy: numbers only by default).
WIDGET_SHOW_TITLES=false

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value is read from
`int.fromEnvironment` / `bool.fromEnvironment` / `String.fromEnvironment` with a safe
default.

### 2b. M6 Backup Vault — `.env.example`

# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M6 Backup Vault
# Version Stamp : v1.0
# ------------------------------------------------------------
# These are NON-SECRET tunables only. No credentials, tokens or
# keys exist in this module, and none may be introduced.
# ============================================================

# The cipher named in the backup metadata (informational).
BACKUP_CIPHER=AES-256-GCM

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value is read from
`int.fromEnvironment` / `bool.fromEnvironment` / `String.fromEnvironment` with a safe
default.

### 2c. M7 Grid Presenter — `.env.example`

# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M7 Grid Presenter
# Version Stamp : v1.0
# ------------------------------------------------------------
# These are NON-SECRET tunables only. No credentials, tokens or
# keys exist in this module, and none may be introduced.
# ============================================================

# The timezone offset M7 uses when asking M4 for 'today', in minutes.
DEFAULT_TZ_OFFSET_MIN=0

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value is read from
`int.fromEnvironment` / `bool.fromEnvironment` / `String.fromEnvironment` with a safe
default.

---

## 3. How to run the three suites (reproduce the 5/5 each)

From the project root, with the pinned `pubspec.yaml` and the committed `build.yaml`:

```
flutter pub get
dart run build_runner build
flutter test tests/test_m5_widget_bridge.dart
flutter test tests/test_m6_backup_vault.dart
flutter test tests/test_m7_grid_presenter.dart
```

Each should end with `All tests passed!` (5 checks each). The `[M5] E1/E7/E8`, `[M6] E1/E7/E9`
and `[M7] E1/E4` lines are the modules' own deliberate error-case output, not failures.
