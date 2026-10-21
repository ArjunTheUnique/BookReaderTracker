# SECTION 5 — THE TWO FIXED FILES (plus the five INT-1 files at v1.0.1)

## 5a. `src/modules/m6_backup_vault_adapters.dart` (FIXED — v1.0.1)

```dart
// ============================================================
// PLATFORM EDGE — M6 Backup Vault adapters
// Version Stamp : v1.0.1  (compile fix: crypto import is prefixed)
// Pairs with    : src/modules/m6_backup_vault.dart
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   M6's logic must not import dart:io or the crypto package directly.
//   This is the edge: the only place those appear. The module declares
//   the FileVault, Cipher and LibraryVaultPort ports; this file
//   implements them for a real device.
//
//   It is NOT imported by the module or by the module's test. It IS
//   imported by INT-1's wiring, which is where the compile errors this
//   version fixes were first seen.
//
// NOTE: the `cryptography` package also exports a class named `Cipher`,
//   which collided with M6's own `Cipher`. The crypto import is therefore
//   prefixed `crypto.` so M6's port name wins.
//
// DO NOT put business rules here — only transport.
// ============================================================

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart' as crypto;

import 'm1_library_store.dart';
import 'm6_backup_vault.dart';

/// The real file edge: reads and writes the .rtbk file with dart:io.
class IoFileVault implements FileVault {
  @override
  Future<void> write(String uri, List<int> bytes) async {
    try {
      await File(uri).writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw VaultIoError('$e');
    }
  }

  @override
  Future<List<int>> read(String uri) async {
    try {
      return await File(uri).readAsBytes();
    } catch (e) {
      throw VaultIoError('$e');
    }
  }
}

/// The real crypto edge: AES-256-GCM via `cryptography`. The 256-bit key
/// is derived from the passphrase with SHA-256; the file layout is
/// nonce || mac || ciphertext. A wrong passphrase or a tampered file
/// fails the GCM tag and becomes E9.
class CryptographyCipher implements Cipher {
  final crypto.AesGcm _algorithm = crypto.AesGcm.with256bits();

  Future<crypto.SecretKey> _key(String passphrase) async {
    final crypto.Hash hash =
        await crypto.Sha256().hash(utf8.encode(passphrase));
    return crypto.SecretKey(hash.bytes);
  }

  @override
  Future<List<int>> encrypt(List<int> plain, String passphrase) async {
    final crypto.SecretKey key = await _key(passphrase);
    final List<int> nonce = _algorithm.newNonce();
    final crypto.SecretBox box =
        await _algorithm.encrypt(plain, secretKey: key, nonce: nonce);
    return <int>[...nonce, ...box.mac.bytes, ...box.cipherText];
  }

  @override
  Future<List<int>> decrypt(List<int> cipher, String passphrase) async {
    try {
      final int nonceLen = _algorithm.nonceLength;
      const int macLen = 16;
      final List<int> nonce = cipher.sublist(0, nonceLen);
      final crypto.Mac mac =
          crypto.Mac(cipher.sublist(nonceLen, nonceLen + macLen));
      final List<int> text = cipher.sublist(nonceLen + macLen);
      final crypto.SecretKey key = await _key(passphrase);
      return await _algorithm.decrypt(
          crypto.SecretBox(text, nonce: nonce, mac: mac),
          secretKey: key);
    } catch (e) {
      throw CipherError('$e');
    }
  }
}

/// The M1 seam for M6.
///
/// NOTE: `snapshot()` works today (M1 read_catalog). `atomicReplace()`
/// CANNOT be implemented, because M1 v1.0.2 exposes no restore/replace
/// API. This is M6 finding F1 — an M1 fix order is required to add an
/// atomic `restore_all` operation before M6 can restore into real data.
class M1LibraryVault implements LibraryVaultPort {
  M1LibraryVault(this.store);
  final M1LibraryStore store;

  @override
  Future<Map<String, dynamic>> snapshot() async {
    final Map<String, dynamic> r = await store.handle(<String, dynamic>{
      'op': 'read_catalog',
      'payload': <String, dynamic>{},
      'idempotency_key': null,
      'schema_version': 1,
    });
    return (r['data'] as Map).cast<String, dynamic>();
  }

  @override
  Future<void> atomicReplace(Map<String, dynamic> snapshot) async {
    throw UnimplementedError(
        'M1 v1.0.2 has no atomic-replace API (M6 finding F1). '
        'Add an M1 restore_all operation first.');
  }

  @override
  Future<String> healthCheck() => store.healthCheck();
}
```

## 5b. `src/modules/m2_book_intake_adapters.dart` (FIXED — v1.0.1)

```dart
// ============================================================
// PLATFORM EDGE — M2 Book Intake adapters
// Version Stamp : v1.0.1  (compile fix: file_picker 13 API)
// Pairs with    : src/modules/m2_book_intake.dart
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   M2's logic must not touch file_picker, dart:io, pdfx or epubx
//   directly — that keeps the module testable with fakes. This file
//   is the "edge": the only place those platform packages appear.
//   The module declares the ports (FileAccess, PageExtractor); this
//   file implements them for a real device.
//
//   It is NOT imported by the module or by the test suite, so the
//   tests stay free of platform plugins. The app shell wires these
//   adapters in at startup.
//
// DO NOT put business rules here — only transport. All decisions
// live in m2_book_intake.dart.
// ============================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart' as epubx;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import 'm1_library_store.dart';
import 'm2_book_intake.dart';

/// Adapts the frozen M1 module to the [LibraryStorePort] interface M2
/// depends on. Dart is nominally typed, so M1LibraryStore does not
/// automatically satisfy the port; this one-line wrapper is the wiring
/// the app shell uses at startup.
class M1LibraryStorePort implements LibraryStorePort {
  M1LibraryStorePort(this.store);
  final M1LibraryStore store;

  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope) =>
      store.handle(envelope);

  @override
  Future<String> healthCheck() => store.healthCheck();
}

/// The real file edge: uses file_picker to choose, dart:io to store.
class FilePickerFileAccess implements FileAccess {
  @override
  Future<PickedFile> pickAndRead() async {
    // file_picker 13: a STATIC pickFile() returns one PlatformFile, and
    // the bytes are read with readAsBytes() (there is no .bytes field).
    final PlatformFile? picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'epub'],
    );
    if (picked == null) {
      // A cancelled picker is treated as a refused permission (C7).
      throw FileAccessDenied('no file selected');
    }
    try {
      final Uint8List bytes = await picked.readAsBytes();
      return PickedFile(name: picked.name, bytes: bytes);
    } catch (e) {
      throw FileAccessDenied('file bytes unavailable (permission?): $e');
    }
  }

  @override
  Future<String> copyToAppStorage(String name, List<int> bytes) async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final File target = File('${dir.path}/$name');
      // Write then flush, so a crash cannot leave a half-written file
      // that later looks "corrupt" to the extractor.
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (e) {
      throw StorageCopyFailed('$e');
    }
  }

  @override
  Future<int> freeBytes() async {
    // Dart has no portable "free space" API on mobile. The copy above
    // still guards with try/catch → E7, so this reports "assume room".
    // A platform-specific implementation can replace this later.
    return 1 << 40;
  }
}

/// The real extraction edge: pdfx for PDF, epubx for EPUB.
class PdfEpubPageExtractor implements PageExtractor {
  @override
  Future<int> pageCount(String name, List<int> bytes) async {
    final String lower = name.toLowerCase();
    try {
      if (lower.endsWith('.pdf')) {
        // PDF has a real, fixed page count.
        final pdfx.PdfDocument doc =
            await pdfx.PdfDocument.openData(Uint8List.fromList(bytes));
        final int n = doc.pagesCount;
        await doc.close();
        return n;
      }
      if (lower.endsWith('.epub')) {
        // EPUB is reflowable — no fixed pages. Per the order's ruling,
        // total_pages = the spine item count (epubx exposes it as
        // Chapters, which is built from the spine).
        final epubx.EpubBook book = await epubx.EpubReader.readBook(bytes);
        return book.Chapters?.length ?? 0;
      }
    } catch (e) {
      throw ExtractionFailed('$e');
    }
    throw ExtractionFailed('unsupported extension for $name');
  }
}
```

## 5c. `tests/test_integration_end_to_end.dart` (passport now v1.0.1)

```dart
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
```

## 5d. `src/app/wiring.dart` (unchanged)

```dart
// ============================================================
// INTEGRATION FILE — INT-1 src/app/wiring.dart  (COMPOSITION ROOT)
// Version Stamp : v1.0
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   This is the ONLY place that knows the concrete adapters. Every
//   module is built here and injected through its port. No module
//   imports another module; they meet only here.
//
// PORTS WIRED HERE (INT-1 section 2)
//   LibraryStorePort  -> M1LibraryStorePort        (M1 -> M2/M6)
//   FileAccess        -> FilePickerFileAccess      (M2)
//   PageExtractor     -> PdfEpubPageExtractor      (M2)
//   Clock             -> SystemClock               (M4, M7)
//   DailySourcePort   -> _M1DailySource            (M4 over M1)
//   WidgetHost        -> HomeWidgetHost            (M5)
//   FileVault/Cipher  -> IoFileVault/Cryptography  (M6)
//   CatalogPort       -> _M1Catalog                (M7 over M1)
//   DailyViewPort     -> _M4DailyView              (M7 over M4)
//   ProgressLoggerPort-> M1ProgressLogger          (M3 seam - see below)
//
// M3 NOTE: the Progress Logger module has not been delivered yet, so
//   this file defines the ProgressLoggerPort seam and a temporary
//   M1-backed stand-in. When M3's module arrives it replaces the
//   stand-in; nothing else changes.
//
// DO NOT TOUCH the wiring table, the goal_pages source, or the rule
//   that the UI reads view-models from M7 only.
// ============================================================

import 'dart:async';

// M4 and M7 each declare their own Clock / socket ports (separate
// types), so this file uses import prefixes to keep them apart.
import '../modules/m1_library_store.dart';
import '../modules/m2_book_intake.dart';
import '../modules/m2_book_intake_adapters.dart';
import '../modules/m4_daily_engine.dart' as engine;
import '../modules/m5_widget_bridge.dart';
import '../modules/m5_widget_bridge_adapters.dart';
import '../modules/m6_backup_vault.dart';
import '../modules/m6_backup_vault_adapters.dart';
import '../modules/m7_grid_presenter.dart' as m7grid;
import 'routes.dart';

// ---------------------------------------------------------------
// The M3 seam
// ---------------------------------------------------------------

/// The slice of M3 (Progress Logger) the shell needs. Declared here
/// because M3's module has not been delivered yet.
abstract class ProgressLoggerPort {
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input);
  Future<String> healthCheck();
}

/// TEMPORARY stand-in for M3: logs progress straight through M1's
/// update_progress, shaped as M3's contract says. Replace with the real
/// M3 module when it arrives.
class M1ProgressLogger implements ProgressLoggerPort {
  M1ProgressLogger(this.store);
  final M1LibraryStore store;

  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input) async {
    final Map<String, dynamic> r = await store.handle(<String, dynamic>{
      'op': 'update_progress',
      'payload': <String, dynamic>{
        'book_id': input['book_id'],
        'current_page': input['current_page'],
        'read_on': input['read_on'],
      },
      'idempotency_key': input['idempotency_key'],
      'schema_version': 1,
    });
    if (r['ok'] != true) return r;
    final Map<String, dynamic> d = (r['data'] as Map).cast<String, dynamic>();
    return <String, dynamic>{
      'ok': true,
      'data': <String, dynamic>{
        'book_id': d['book_id'],
        'current_page': d['current_page'],
        'pct_read': d['pct_read'],
        'saved': d['saved'],
      },
      'schema_version': 1,
    };
  }

  @override
  Future<String> healthCheck() => store.healthCheck();
}

// ---------------------------------------------------------------
// Pure-Dart adapters (no platform code)
// ---------------------------------------------------------------

/// M4's DailySourcePort over M1.
class _M1DailySource implements engine.DailySourcePort {
  _M1DailySource(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

/// M7's CatalogPort over M1.
class _M1Catalog implements m7grid.CatalogPort {
  _M1Catalog(this._store);
  final M1LibraryStore _store;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _store.handle(e);
  @override
  Future<String> healthCheck() => _store.healthCheck();
}

/// M7's DailyViewPort over M4.
class _M4DailyView implements m7grid.DailyViewPort {
  _M4DailyView(this._engine);
  final engine.M4DailyEngine _engine;
  @override
  Future<Map<String, dynamic>> handle(Map<String, dynamic> e) => _engine.handle(e);
  @override
  Future<String> healthCheck() => _engine.healthCheck();
}

/// The one clock handed to both M4 and M7. It implements BOTH modules'
/// Clock interfaces, which are separate types (INT-1 finding F3).
class SystemClock implements engine.Clock, m7grid.Clock {
  @override
  DateTime now() => DateTime.now();
}

// ---------------------------------------------------------------
// The wiring
// ---------------------------------------------------------------

/// The assembled app: every module, ready, reached only through ports.
class AppWiring {
  AppWiring({
    required this.store,
    required this.intake,
    required this.progress,
    required this.daily,
    required this.widget,
    required this.backup,
    required this.grid,
    required this.routes,
    required this.clock,
    this.timezoneOffsetMin = 330,
  });

  final M1LibraryStore store;
  final M2BookIntake intake;
  final ProgressLoggerPort progress;
  final engine.M4DailyEngine daily;
  final M5WidgetBridge widget;
  final M6BackupVault backup;
  final m7grid.M7GridPresenter grid;
  final AppRoutes routes;
  final SystemClock clock;
  final int timezoneOffsetMin;

  /// Boot health (C1): seed if empty, then probe every seam.
  /// Returns 'ok' only when the whole chain answers.
  Future<String> bootHealth() async {
    await store.seedIfEmpty();
    final String m1 = await store.healthCheck();
    if (m1 != 'ok') return 'degraded: m1=$m1';
    final String m4 = await daily.healthCheck();
    if (m4 != 'ok') return 'degraded: m4=$m4';
    final String m7 = await grid.healthCheck();
    if (m7 != 'ok') return 'degraded: m7=$m7';
    return 'ok';
  }

  /// PRODUCTION: build the real adapters and open the app-private DB.
  static Future<AppWiring> production() async {
    final M1LibraryStore store = await M1LibraryStore.openDefault();
    final SystemClock clock = SystemClock();
    final engine.M4DailyEngine daily =
        engine.M4DailyEngine(m1: _M1DailySource(store), clock: clock);
    return AppWiring(
      store: store,
      intake: M2BookIntake(
        fileAccess: FilePickerFileAccess(),
        extractor: PdfEpubPageExtractor(),
        m1: M1LibraryStorePort(store),
      ),
      progress: M1ProgressLogger(store),
      daily: daily,
      widget: M5WidgetBridge(host: HomeWidgetHost()),
      backup: M6BackupVault(
        files: IoFileVault(),
        cipher: CryptographyCipher(),
        library: M1LibraryVault(store),
      ),
      grid: m7grid.M7GridPresenter(
        catalog: _M1Catalog(store),
        daily: _M4DailyView(daily),
        clock: clock,
      ),
      routes: const AppRoutes(),
      clock: clock,
    );
  }

  /// TEST: same wiring, but every platform edge is injected. Used by the
  /// end-to-end suite so no plugin is called.
  static AppWiring forTest({
    required M1LibraryStore store,
    required WidgetHost widgetHost,
    FileAccess? fileAccess,
    PageExtractor? extractor,
    FileVault? files,
    Cipher? cipher,
    LibraryVaultPort? library,
    SystemClock? clock,
    int timezoneOffsetMin = 330,
  }) {
    final SystemClock theClock = clock ?? SystemClock();
    final engine.M4DailyEngine daily =
        engine.M4DailyEngine(m1: _M1DailySource(store), clock: theClock);
    return AppWiring(
      store: store,
      intake: M2BookIntake(
        fileAccess: fileAccess ?? _NoFileAccess(),
        extractor: extractor ?? _NoExtractor(),
        m1: M1LibraryStorePort(store),
      ),
      progress: M1ProgressLogger(store),
      daily: daily,
      widget: M5WidgetBridge(host: widgetHost),
      backup: M6BackupVault(
        files: files ?? _MemoryVault(),
        cipher: cipher ?? _PassthroughCipher(),
        library: library ?? M1LibraryVault(store),
      ),
      grid: m7grid.M7GridPresenter(
        catalog: _M1Catalog(store),
        daily: _M4DailyView(daily),
        clock: theClock,
        timezoneOffsetMin: timezoneOffsetMin,
      ),
      routes: const AppRoutes(),
      clock: theClock,
      timezoneOffsetMin: timezoneOffsetMin,
    );
  }
}

// ---------------------------------------------------------------
// Harmless defaults for forTest when a port is not overridden.
// ---------------------------------------------------------------

class _NoFileAccess implements FileAccess {
  @override
  Future<PickedFile> pickAndRead() async =>
      throw FileAccessDenied('no file access in test');
  @override
  Future<String> copyToAppStorage(String name, List<int> bytes) async =>
      throw StorageCopyFailed('no file access in test');
  @override
  Future<int> freeBytes() async => 1 << 40;
}

class _NoExtractor implements PageExtractor {
  @override
  Future<int> pageCount(String name, List<int> bytes) async =>
      throw ExtractionFailed('no extractor in test');
}

class _MemoryVault implements FileVault {
  final Map<String, List<int>> store = <String, List<int>>{};
  @override
  Future<void> write(String uri, List<int> bytes) async =>
      store[uri] = List<int>.from(bytes);
  @override
  Future<List<int>> read(String uri) async {
    final List<int>? b = store[uri];
    if (b == null) throw VaultIoError('missing');
    return b;
  }
}

class _PassthroughCipher implements Cipher {
  @override
  Future<List<int>> encrypt(List<int> plain, String passphrase) async =>
      List<int>.from(plain);
  @override
  Future<List<int>> decrypt(List<int> cipher, String passphrase) async =>
      List<int>.from(cipher);
}
```

## 5e. `src/app/routes.dart`, `src/app/app_shell.dart`, `src/main.dart` (unchanged)

```dart
// ============================================================
// INTEGRATION FILE — INT-1 src/app/routes.dart
// Version Stamp : v1.0
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   A widget tap (M5) produces a deep-link string like
//   "shelf://book/<id>". This file turns that string into a
//   screen target the shell can open — including on a cold start.
//
// DO NOT TOUCH the route format: M5 mints it and the native widget
// passes it back, so both sides must agree.
// ============================================================

/// Where a deep link should land.
class RouteTarget {
  RouteTarget.book(this.id) : view = 'book';
  RouteTarget.category(this.id) : view = 'category';

  /// 'book' or 'category' — matches M7's `view` values.
  final String view;

  /// The id M7 will be asked for.
  final String id;

  @override
  String toString() => 'RouteTarget($view, $id)';
}

/// Maps the widget's tap route to the right screen.
class AppRoutes {
  const AppRoutes();

  /// Parse `shelf://book/<id>` or `shelf://category/<id>`.
  /// Returns null for anything else, so the shell can fall back home.
  RouteTarget? resolve(String route) {
    final Uri? uri = Uri.tryParse(route);
    if (uri == null || uri.scheme != 'shelf') return null;
    final String id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (id.isEmpty) return null;
    switch (uri.host) {
      case 'book':
        return RouteTarget.book(id);
      case 'category':
        return RouteTarget.category(id);
      default:
        return null;
    }
  }
}
```

```dart
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
```

```dart
// ============================================================
// INTEGRATION FILE — INT-1 src/main.dart  (app entry point)
// Version Stamp : v1.0
// Part of       : INT-1 App Shell & Wiring
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   Boots the app: builds the composition root (wiring), which opens
//   M1 and injects every module through its port, then hands the
//   shell the assembled app.
// ============================================================

import 'package:flutter/material.dart';

import 'app/app_shell.dart';
import 'app/wiring.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppWiring wiring = await AppWiring.production();
  runApp(ShelfApp(wiring: wiring));
}
```
