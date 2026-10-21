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
