// ============================================================
// MODULE PASSPORT — M2 Book Intake
// Version Stamp : v1.0
// Module File   : src/modules/m2_book_intake.dart
// Test File     : tests/test_m2_book_intake.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.1 (Table 2A, row M2)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Take a book — a device ebook (PDF/EPUB) or a manual/offline
//   entry — validate it, import the file if present, and hand the
//   clean result to M1. It never touches the database itself.
//
// MACHINE SOCKET CONTRACT SUMMARY
//   INPUT  : { category_id, source, file_uri?, title, total_pages?,
//              cover_ref?, idempotency_key }
//   OUTPUT success : { ok:true, data:{book_id, category_id,
//                      total_pages, source}, schema_version:1 }
//   OUTPUT failure : { ok:false, error:{code, message, field?} }
//   ERROR SHAPES : E1 INVALID_INPUT · E2 OUT_OF_RANGE ·
//                  E3 LIMIT_EXCEEDED (passed through from M1) ·
//                  E4 NOT_FOUND (passed through from M1) ·
//                  E6 UNSUPPORTED_FORMAT · E7 STORAGE_ERROR ·
//                  E8 PERMISSION_DENIED
//
// CONTROL PATH SUMMARY (the C-switches inside this file)
//   C3 source branch — "manual" needs total_pages; "device_file"
//      needs a file, format/size checks, a copy and an extraction.
//   C2 capacity — DELEGATED. M2 never decides the cap; M1 enforces it.
//   C7 permission gate — a refused pick becomes E8, never a crash.
//
// DATA PATH SUMMARY (the D-pipes inside this file)
//   D3 ebook import pipe — validate → copy to app storage → extract
//      page count → call M1 add_book.
//   D1 catalog — DELEGATED; the write is M1's.
//
// SAFE TO EDIT BY HAND GUIDE
//   Everything under ZONE 1: kMaxImportMb, kParseTimeoutSeconds,
//   kRetryBackoffSeconds, kTitleMin/kTitleMax, kTotalPagesMin/
//   kTotalPagesMax, kAllowedExtensions, kBytesPerMb, and every
//   log message.
//
// DO NOT TOUCH WARNING
//   The IN/OUT contract field names and types, the error codes,
//   the delegation to M1 (M2 must NEVER write to the DB itself),
//   and the port shapes declared in ZONE 2.
//
// 2 AM TROUBLESHOOTING HINT
//   On any failure this module returns
//   { ok:false, error:{ code:"E*", message:"...", field? } } and
//   prints "[M2] <CODE>: <detail>". If E6 keeps appearing on a file
//   that looks fine, the parser could not read it — fall back to
//   manual entry (which always works). If E8, the user refused file
//   access; re-offer manual entry.
// ============================================================

import 'dart:async';

// ============================================================
// === ZONE 1: SAFE TO EDIT CONFIGURATION & RULES ===
// Every adjustable number, label and threshold lives here and
// nowhere else.
// ============================================================

/// The contract version this module speaks.
const int kSchemaVersion = 1;

/// Largest file M2 will import, in MB. Must default to a safe value.
const int kMaxImportMb = int.fromEnvironment('MAX_IMPORT_MB', defaultValue: 100);

/// Log verbosity label (kept here so no call site spells a literal).
const String kLogLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');

/// Title length bounds (characters, inclusive).
const int kTitleMin = 1;
const int kTitleMax = 200;

/// Manual page-count bounds (inclusive).
const int kTotalPagesMin = 1;
const int kTotalPagesMax = 20000;

/// The only two allowed values for `source`.
const List<String> kSources = <String>['device_file', 'manual'];

/// The only file extensions M2 will accept for a device file.
const List<String> kAllowedExtensions = <String>['.pdf', '.epub'];

/// One parse attempt may run this long before it is abandoned.
const int kParseTimeoutSeconds = 15;

/// Backoff (seconds) between parse attempts. Length = number of retries.
const List<int> kRetryBackoffSeconds = <int>[1, 2];

/// Bytes in a megabyte (used for the import cap).
const int kBytesPerMb = 1024 * 1024;

// ============================================================
// === ZONE 2: BOUNDARY VALIDATION & MACHINE SOCKET CONTRACT ===
// The ports M2 depends on, plus every check a caller's input
// passes through before any work happens.
// ============================================================

/// One file handed back by the platform edge.
class PickedFile {
  PickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Raised by the platform edge when the user refuses file access.
class FileAccessDenied implements Exception {
  FileAccessDenied([this.message = 'file access denied']);
  final String message;
  @override
  String toString() => message;
}

/// Raised by the platform edge when a file cannot be copied.
class StorageCopyFailed implements Exception {
  StorageCopyFailed([this.message = 'copy failed']);
  final String message;
  @override
  String toString() => message;
}

/// Raised by an extractor when a page count cannot be obtained.
class ExtractionFailed implements Exception {
  ExtractionFailed([this.message = 'extraction failed']);
  final String message;
  @override
  String toString() => message;
}

/// The ONLY place M2 touches the platform for files. The real
/// implementation (file_picker + dart:io) lives in the adapter file
/// m2_book_intake_adapters.dart, so this module never imports it.
abstract class FileAccess {
  /// Return the picked file's bytes and name, or throw
  /// [FileAccessDenied] if the user refuses.
  Future<PickedFile> pickAndRead();

  /// Copy bytes into app-private storage and return the stored path.
  Future<String> copyToAppStorage(String name, List<int> bytes);

  /// Bytes currently free on the device (for the storage guard).
  Future<int> freeBytes();
}

/// Page-count extraction. pdfx (PDF) and epubx (EPUB) live behind this,
/// so the module never imports them and tests can inject a fake.
abstract class PageExtractor {
  Future<int> pageCount(String name, List<int> bytes);
}

/// The slice of M1's socket that M2 depends on. Declared here so M2
/// depends on the CONTRACT, not on M1's file — M1LibraryStore
/// satisfies this structurally. This is what keeps M2 from importing
/// the database layer directly.
abstract class LibraryStorePort {
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope);
  Future<String> healthCheck();
}

/// The one entry point. Takes M2's input object, returns a success or
/// failure map. Never throws for a contract violation.
class M2BookIntake {
  M2BookIntake({
    required this.fileAccess,
    required this.extractor,
    required this.m1,
    int? maxImportMb,
    int? parseTimeoutSeconds,
    List<int>? retryBackoffSeconds,
  })  : maxImportMb = maxImportMb ?? kMaxImportMb,
        parseTimeoutSeconds = parseTimeoutSeconds ?? kParseTimeoutSeconds,
        retryBackoffSeconds = retryBackoffSeconds ?? kRetryBackoffSeconds;

  final FileAccess fileAccess;
  final PageExtractor extractor;
  final LibraryStorePort m1;

  /// Tunables exposed for tests; the defaults are the ZONE 1 values.
  final int maxImportMb;
  final int parseTimeoutSeconds;
  final List<int> retryBackoffSeconds;

  /// Keys a caller may send; anything else is E1.
  static const Set<String> _allowedKeys = <String>{
    'category_id',
    'source',
    'file_uri',
    'title',
    'total_pages',
    'cover_ref',
    'idempotency_key',
  };

  /// Keys that must always be present.
  static const Set<String> _requiredKeys = <String>{
    'category_id',
    'source',
    'title',
    'idempotency_key',
  };

  /// THE socket. Validates the input, branches on source, then calls M1.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input) async {
    // --- boundary checks, in the order the order specifies ----------
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

    final Object? categoryId = input['category_id'];
    if (categoryId is! String || categoryId.isEmpty) {
      return _fail('E1', 'category_id must be a non-empty string.', 'category_id');
    }
    final Object? title = input['title'];
    if (title is! String || title.length < kTitleMin || title.length > kTitleMax) {
      return _fail('E1', 'title must be $kTitleMin-$kTitleMax characters.', 'title');
    }
    final Object? source = input['source'];
    if (source is! String || !kSources.contains(source)) {
      return _fail('E1', 'source must be one of $kSources.', 'source');
    }
    final Object? idem = input['idempotency_key'];
    if (idem is! String || idem.isEmpty) {
      return _fail('E1', 'idempotency_key must be a non-empty string.', 'idempotency_key');
    }
    final Object? coverRaw = input['cover_ref'];
    if (coverRaw != null && coverRaw is! String) {
      return _fail('E1', 'cover_ref must be a string or null.', 'cover_ref');
    }
    final String? coverRef = coverRaw as String?;

    // --- C3: the source branch decides what happens next ------------
    if (source == 'manual') {
      return _handleManual(
        input: input,
        categoryId: categoryId,
        title: title,
        coverRef: coverRef,
        idem: idem,
      );
    }
    return _handleDeviceFile(
      input: input,
      categoryId: categoryId,
      title: title,
      coverRef: coverRef,
      idem: idem,
    );
  }

  // ============================================================
  // === ZONE 3: CONTROL PATH FUNCTIONS (THE SWITCHES) ===
  // Pure decisions and business rules. No I/O, no formatting.
  // ============================================================

  /// C3 (manual branch). A hand-logged book must carry its own page
  /// count, because there is no file to read it from.
  Future<Map<String, dynamic>> _handleManual({
    required Map<String, dynamic> input,
    required String categoryId,
    required String title,
    required String? coverRef,
    required String idem,
  }) async {
    final Object? tp = input['total_pages'];
    if (tp is! int) {
      return _fail(
          'E1', 'total_pages is required and must be an integer for source=manual.', 'total_pages');
    }
    if (tp < kTotalPagesMin || tp > kTotalPagesMax) {
      return _fail('E2', 'total_pages must be $kTotalPagesMin-$kTotalPagesMax.', 'total_pages');
    }
    return _callM1(
      categoryId: categoryId,
      title: title,
      source: 'manual',
      totalPages: tp,
      filePath: null,
      coverRef: coverRef,
      idemKey: idem,
    );
  }

  /// C3 (device_file branch). A device book carries a file, so its page
  /// count comes from the file, not the caller.
  Future<Map<String, dynamic>> _handleDeviceFile({
    required Map<String, dynamic> input,
    required String categoryId,
    required String title,
    required String? coverRef,
    required String idem,
  }) async {
    final Object? uri = input['file_uri'];
    if (uri is! String || uri.isEmpty) {
      return _fail('E1', 'file_uri is required when source is device_file.', 'file_uri');
    }

    // Extension check FIRST — cheapest gate, before any read.
    final String lower = uri.toLowerCase();
    final bool extensionOk = kAllowedExtensions.any((String e) => lower.endsWith(e));
    if (!extensionOk) {
      return _fail('E6', 'Only ${kAllowedExtensions.join(", ")} files are supported.', 'file_uri');
    }

    // Read the file through the port (C7 permission gate).
    PickedFile picked;
    try {
      picked = await fileAccess.pickAndRead();
    } on FileAccessDenied catch (e) {
      return _fail('E8', 'Permission to read the file was refused: ${e.message}');
    } catch (e) {
      return _fail('E6', 'The file could not be read: $e');
    }

    // Size cap — checked immediately, before any copy.
    final int maxBytes = maxImportMb * kBytesPerMb;
    if (picked.bytes.length > maxBytes) {
      return _fail('E6', 'File is larger than the $maxImportMb MB import cap.');
    }

    // Free-space guard (S8): refuse early rather than half-copy.
    try {
      final int free = await fileAccess.freeBytes();
      if (free < picked.bytes.length) {
        return _fail('E7', 'Not enough free space to copy the file.');
      }
    } catch (e) {
      return _fail('E7', 'Could not check free space: $e');
    }

    // Copy into app-private storage (S8).
    String storedPath;
    try {
      storedPath = await fileAccess.copyToAppStorage(picked.name, picked.bytes);
    } on StorageCopyFailed catch (e) {
      return _fail('E7', 'Copy to app storage failed: ${e.message}');
    } catch (e) {
      return _fail('E7', 'Copy to app storage failed: $e');
    }

    // Extract the page count (S3: bounded, retried with backoff).
    int pages;
    try {
      pages = await _extractWithRetry(picked.name, picked.bytes);
    } on ExtractionFailed catch (e) {
      return _fail('E6', 'Could not extract a page count: ${e.message}');
    }
    if (pages < kTotalPagesMin || pages > kTotalPagesMax) {
      return _fail('E6',
          'Extracted page count $pages is outside $kTotalPagesMin-$kTotalPagesMax.');
    }

    return _callM1(
      categoryId: categoryId,
      title: title,
      source: 'device_file',
      totalPages: pages,
      filePath: storedPath,
      coverRef: coverRef,
      idemKey: idem,
    );
  }

  // ============================================================
  // === ZONE 4: DATA PATH, FAILURE-SHIELD & HEALTH-PROBE (PIPES) ===
  // Retry/backoff, the M1 call, and the smoke probe.
  // ============================================================

  /// S3: try the extractor, bounded by a timeout, retrying with
  /// backoff. Gives up after the configured attempts and throws
  /// [ExtractionFailed] so the caller maps it to E6.
  Future<int> _extractWithRetry(String name, List<int> bytes) async {
    Object? last;
    final int attempts = retryBackoffSeconds.length + 1;
    for (int i = 0; i < attempts; i++) {
      try {
        return await extractor
            .pageCount(name, bytes)
            .timeout(Duration(seconds: parseTimeoutSeconds));
      } on ExtractionFailed catch (e) {
        last = e;
      } on TimeoutException catch (e) {
        last = e;
      } catch (e) {
        last = e;
      }
      if (i < retryBackoffSeconds.length) {
        final int s = retryBackoffSeconds[i];
        if (s > 0) await Future<void>.delayed(Duration(seconds: s));
      }
    }
    throw ExtractionFailed('$last');
  }

  /// D3 → D1 hand-off: build an M1 `add_book` envelope and pass it
  /// through. M1's own failure shapes (E3/E4/E7...) come back unchanged.
  Future<Map<String, dynamic>> _callM1({
    required String categoryId,
    required String title,
    required String source,
    required int totalPages,
    required String? filePath,
    required String? coverRef,
    required String idemKey,
  }) async {
    final String bookId = _bookIdForKey(idemKey);
    final Map<String, dynamic> envelope = <String, dynamic>{
      'op': 'add_book',
      'payload': <String, dynamic>{
        'book_id': bookId,
        'category_id': categoryId,
        'title': title,
        'total_pages': totalPages,
        'source': source,
        'file_path': filePath,
        'cover_ref': coverRef,
      },
      'idempotency_key': idemKey,
      'schema_version': kSchemaVersion,
    };

    Map<String, dynamic> out;
    try {
      out = await m1.handle(envelope);
    } catch (e) {
      return _fail('E7', 'M1 call failed: $e');
    }

    if (out['ok'] == true) {
      final Map<String, dynamic> data =
          (out['data'] as Map).cast<String, dynamic>();
      return _ok(<String, dynamic>{
        'book_id': data['book_id'],
        'category_id': data['category_id'],
        'total_pages': totalPages,
        'source': source,
      });
    }

    // Pass M1's failure through unchanged.
    final Map<String, dynamic> err =
        (out['error'] as Map).cast<String, dynamic>();
    return _fail(err['code'] as String, err['message'] as String,
        err['field'] as String?);
  }

  /// Health probe for M6/ops. Confirms the M1 seam answers.
  Future<String> healthCheck() async {
    try {
      final String h = await m1.healthCheck();
      if (h != 'ok') return 'degraded: m1=$h';
      final Map<String, dynamic> r = await m1.handle(<String, dynamic>{
        'op': 'read_catalog',
        'payload': <String, dynamic>{},
        'idempotency_key': null,
        'schema_version': kSchemaVersion,
      });
      if (r['ok'] != true) return 'degraded: m1 read failed';
      return 'ok';
    } catch (e) {
      return 'degraded: $e';
    }
  }

  // --- shared socket shape builders -------------------------------

  Map<String, dynamic> _ok(Map<String, dynamic> data) => <String, dynamic>{
        'ok': true,
        'data': data,
        'schema_version': kSchemaVersion,
      };

  Map<String, dynamic> _fail(String code, String message, [String? field]) {
    // ignore: avoid_print
    print('[M2] $code: $message');
    return <String, dynamic>{
      'ok': false,
      'error': <String, dynamic>{
        'code': code,
        'message': message,
        if (field != null) 'field': field,
      },
    };
  }

  /// Derive a STABLE book id from the idempotency key.
  ///
  /// WHY: M1's replay guard recognises a repeated key but then looks the
  /// book up by the id in the payload. If M2 minted a fresh random id on
  /// every call, a retry would carry a NEW id, the lookup would miss, and
  /// M1 would answer E4 instead of the original success. Deriving the id
  /// from the key means a retry re-sends the SAME id, so M1's replay is a
  /// clean no-op — which is what makes "a repeated key never creates a
  /// second book" true across the seam.
  static String _bookIdForKey(String key) {
    final List<int> b = <int>[];
    for (int i = 0; i < 4; i++) {
      final int v = _stableHash('$i|$key');
      b
        ..add((v >> 24) & 0xFF)
        ..add((v >> 16) & 0xFF)
        ..add((v >> 8) & 0xFF)
        ..add(v & 0xFF);
    }
    // Shape it as a v4-style uuid (M1's contract expects a uuid string).
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final String hex = b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// A small, STABLE string hash (FNV-1a, 32-bit). Stable matters: the
  /// id must be the same across app restarts, so a retry still dedupes.
  static int _stableHash(String s) {
    int h = 2166136261;
    for (final int c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }
}
