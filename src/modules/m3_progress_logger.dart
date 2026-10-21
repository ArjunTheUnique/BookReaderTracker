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
