// ============================================================
// MODULE PASSPORT — M4 Daily Engine
// Version Stamp : v1.0
// Module File   : src/modules/m4_daily_engine.dart
// Test File     : tests/test_m4_daily_engine.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M4)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Compose the day view: given a date and a timezone, return the
//   total pages read today and a per-book percentage, ready for the
//   widget (M5) and the grid (M7). Owns the timezone-aware "today"
//   and the clock-anomaly guard.
//
// MACHINE SOCKET CONTRACT SUMMARY
//   INPUT  : { as_of_date:"YYYY-MM-DD", timezone_offset_min:int }
//   OUTPUT success : { ok:true, data:{ date, total_pages_today,
//                      per_book:[{book_id, pages_today, pct_today}] },
//                      schema_version:1 }
//   OUTPUT failure : { ok:false, error:{code, message, field?} }
//   ERROR SHAPES : E1 INVALID_INPUT · E2 OUT_OF_RANGE ·
//                  E4 NOT_FOUND (passed through from M1)
//
// CONTROL PATH SUMMARY (the C-switch inside this file)
//   C5 daily rollover — M4 owns the timezone-aware "today"; a new
//      date simply yields a fresh (empty) day. There is no reset.
//
// DATA PATH SUMMARY (the D-pipe inside this file)
//   D4 daily aggregate (READ side) — M4 reads M1's day rows and
//      shapes the caller view. It NEVER writes daily_summary.
//
// HONEST SCOPE NOTE
//   M1 already stores the per-day rows. M4 does NOT re-aggregate from
//   the raw log; it reads M1's day rows, applies the anomaly guard and
//   the timezone-aware date, and shapes the payload. Keep it thin.
//
// SAFE TO EDIT BY HAND GUIDE
//   Everything under ZONE 1: kTzMin/kTzMax, kDefaultDailyGoalPages,
//   kSchemaVersion, and every log message.
//
// DO NOT TOUCH WARNING
//   The IN/OUT contract field names and types, the error codes, the
//   rule that M4 writes nothing to the database, and the rule that
//   M4 does not push to the widget (that is M5's job).
//
// 2 AM TROUBLESHOOTING HINT
//   On any failure this module returns
//   { ok:false, error:{ code:"E*", message:"...", field? } } and prints
//   "[M4] <CODE>: <detail>". An EMPTY day is NOT an error — it returns
//   zeros. If you see an "[M4] anomaly:" line, the device clock moved
//   (or M1 handed back a negative); the count was clamped to 0 and no
//   data was harmed.
// ============================================================

import 'dart:async';

// ============================================================
// === ZONE 1: SAFE TO EDIT CONFIGURATION & RULES ===
// ============================================================

/// The contract version this module speaks.
const int kSchemaVersion = 1;

/// Smallest allowed timezone offset, in minutes (UTC-12:00).
const int kTzMin = -720;

/// Largest allowed timezone offset, in minutes (UTC+14:00).
const int kTzMax = 840;

/// The daily page goal, echoed for the widget (M5). Not part of the
/// OUT payload — the registry shape is exact — but exposed as a value.
const int kDefaultDailyGoalPages =
    int.fromEnvironment('DEFAULT_DAILY_GOAL_PAGES', defaultValue: 20);

/// Log verbosity label.
const String kLogLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');

// ============================================================
// === ZONE 2: BOUNDARY VALIDATION & MACHINE SOCKET CONTRACT ===
// ============================================================

/// The injected clock. M4 must never call DateTime.now() directly, so
/// "today" is deterministic in tests and the offset is explicit.
abstract class Clock {
  DateTime now();
}

/// The slice of M1's socket M4 depends on (read_daily + health). Declared
/// here so M4 depends on the CONTRACT, not on M1's file.
abstract class DailySourcePort {
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope);
  Future<String> healthCheck();
}

/// The one entry point. Takes M4's input object, returns a success or
/// failure map. Never throws for a contract violation.
class M4DailyEngine {
  M4DailyEngine({required this.m1, required this.clock});

  final DailySourcePort m1;
  final Clock clock;

  /// Keys a caller may send; anything else is E1.
  static const Set<String> _allowedKeys = <String>{
    'as_of_date',
    'timezone_offset_min',
  };

  /// Keys that must always be present.
  static const Set<String> _requiredKeys = <String>{
    'as_of_date',
    'timezone_offset_min',
  };

  /// The daily goal, echoed for M5's widget payload.
  int get dailyGoalPages => kDefaultDailyGoalPages;

  /// THE socket.
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

    final Object? asOfRaw = input['as_of_date'];
    if (asOfRaw is! String || !isIsoDate(asOfRaw)) {
      return _fail('E1', 'as_of_date must match YYYY-MM-DD.', 'as_of_date');
    }
    final Object? tzRaw = input['timezone_offset_min'];
    if (tzRaw is! int) {
      return _fail('E1', 'timezone_offset_min must be an integer.', 'timezone_offset_min');
    }
    if (tzRaw < kTzMin || tzRaw > kTzMax) {
      return _fail('E2', 'timezone_offset_min must be $kTzMin..$kTzMax.', 'timezone_offset_min');
    }

    // C5: the timezone-aware "today". A clock that has jumped back shows
    // up here as a reported date that is ahead of "today".
    final String today = localToday(tzRaw);
    if (asOfRaw.compareTo(today) > 0) {
      _log('anomaly: as_of_date $asOfRaw is after local today $today '
          '(device clock may have jumped back)');
    }

    // D4 (read side): ask M1 for the day's rows.
    Map<String, dynamic> m1Out;
    try {
      m1Out = await m1.handle(<String, dynamic>{
        'op': 'read_daily',
        'payload': <String, dynamic>{'as_of_date': asOfRaw},
        'idempotency_key': null,
        'schema_version': kSchemaVersion,
      });
    } catch (e) {
      return _fail('E4', 'Could not read the day from M1: $e');
    }

    if (m1Out['ok'] != true) {
      // Pass M1's failure through unchanged (E1/E2/E4/E7...).
      final Map<String, dynamic>? err =
          (m1Out['error'] as Map?)?.cast<String, dynamic>();
      final String code = (err?['code'] as String?) ?? 'E4';
      return _fail(code, (err?['message'] as String?) ?? 'M1 could not compose the day.',
          err?['field'] as String?);
    }

    final Map<String, dynamic> data = (m1Out['data'] as Map).cast<String, dynamic>();
    final List<dynamic> perBookIn = (data['per_book'] as List<dynamic>?) ?? const <dynamic>[];

    // Anomaly guard (S5): never surface a negative.
    final List<Map<String, dynamic>> perBookOut = <Map<String, dynamic>>[];
    int total = 0;
    bool clamped = false;
    for (final dynamic entry in perBookIn) {
      final Map<String, dynamic> m = (entry as Map).cast<String, dynamic>();
      final int rawPages = (m['pages_today'] as int?) ?? 0;
      final int pages = clampPagesToday(rawPages);
      if (pages != rawPages) clamped = true;
      final double rawPct = (m['pct_today'] as num?)?.toDouble() ?? 0.0;
      perBookOut.add(<String, dynamic>{
        'book_id': m['book_id'],
        'pages_today': pages,
        'pct_today': clampPct(rawPct),
      });
      total += pages;
    }
    if (clamped) {
      _log('anomaly: negative pages_today clamped to 0');
    }

    return _ok(<String, dynamic>{
      'date': asOfRaw,
      'total_pages_today': total,
      'per_book': perBookOut,
    });
  }

  // ============================================================
  // === ZONE 3: CONTROL PATH FUNCTIONS (THE SWITCHES) ===
  // Pure decisions and rules. No I/O.
  // ============================================================

  /// C5: the local calendar date for a given offset, derived from the
  /// injected clock — never from DateTime.now().
  String localToday(int offsetMin) {
    final DateTime local =
        clock.now().toUtc().add(Duration(minutes: offsetMin));
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  /// S5: a page count can never be negative — a backwards clock jump is
  /// the usual cause, so clamp rather than surface a nonsense number.
  int clampPagesToday(int value) => value < 0 ? 0 : value;

  /// A percentage always lives in 0..100.
  double clampPct(double value) {
    if (value < 0) return 0.0;
    if (value > 100) return 100.0;
    return value;
  }

  /// True only for a well-formed calendar date in "YYYY-MM-DD".
  bool isIsoDate(String value) {
    final RegExp re = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!re.hasMatch(value)) return false;
    try {
      final DateTime parsed = DateTime.parse(value);
      final String round = '${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}';
      return round == value;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // === ZONE 4: DATA PATH, FAILURE-SHIELD & HEALTH-PROBE (PIPES) ===
  // ============================================================

  /// Health probe. Confirms the M1 seam answers.
  Future<String> healthCheck() async {
    try {
      final String h = await m1.healthCheck();
      if (h != 'ok') return 'degraded: m1=$h';
      return 'ok';
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
    print('[M4] $code: $message');
    return <String, dynamic>{
      'ok': false,
      'error': <String, dynamic>{
        'code': code,
        'message': message,
        if (field != null) 'field': field,
      },
    };
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[M4] $message');
  }
}
