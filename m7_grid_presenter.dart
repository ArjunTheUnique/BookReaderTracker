// ============================================================
// MODULE PASSPORT — M7 Grid Presenter
// Version Stamp : v1.0
// Module File   : src/modules/m7_grid_presenter.dart
// Test File     : tests/test_m7_grid_presenter.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M7)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Build the exact view-models the home grid and book tiles render,
//   enforcing the 6-category x 6-book no-scroll shape. Reads the
//   catalog from M1 and today's percentages from M4. Never writes.
//
// MACHINE SOCKET CONTRACT SUMMARY
//   INPUT  : { view:"home"|"category"|"book", category_id?, book_id? }
//   OUTPUT success : { ok:true, data:<per view>, schema_version:1 }
//   OUTPUT failure : { ok:false, error:{code, message, field?} }
//   ERROR SHAPES : E1 INVALID_INPUT · E4 NOT_FOUND
//
// CONTROL PATH SUMMARY (the C-switch inside this file)
//   C1 launch — the home view reflects the 6 categories M1 seeds.
//
// DATA PATH SUMMARY (the D-pipe inside this file)
//   D7 tile view-model pipe — compose each tile: id, title,
//      cover_ref, pct_today.
//
// SCOPE NOTE
//   M7 is READ-ONLY. It calls M1 read_catalog and M4 for percentages;
//   it never writes and never computes a percentage itself.
//
// SAFE TO EDIT BY HAND GUIDE
//   Everything under ZONE 1: kCategoryCount, kDefaultTzOffsetMin,
//   kTzMin/kTzMax, log messages, tile field order in Zone 4.
//
// DO NOT TOUCH WARNING
//   The IN/OUT contract field names and types, the error codes, and
//   the rule that M7 never writes and never computes a percentage.
//
// 2 AM TROUBLESHOOTING HINT
//   On any failure this module returns
//   { ok:false, error:{ code:"E*", message:"...", field? } } and prints
//   "[M7] <CODE>: <detail>". An EMPTY catalog is a SUCCESS — a fresh
//   library returns 6 empty tiles, not an error. E4 means the id you
//   asked for does not exist.
// ============================================================

import 'dart:async';

// ============================================================
// === ZONE 1: SAFE TO EDIT CONFIGURATION & RULES ===
// ============================================================

/// The contract version this module speaks.
const int kSchemaVersion = 1;

/// The grid always shows this many category tiles.
const int kCategoryCount = 6;

/// Smallest allowed timezone offset, in minutes.
const int kTzMin = -720;

/// Largest allowed timezone offset, in minutes.
const int kTzMax = 840;

/// The offset M7 uses when asking M4 for "today" (build-time tunable).
const int kDefaultTzOffsetMin =
    int.fromEnvironment('DEFAULT_TZ_OFFSET_MIN', defaultValue: 0);

/// Log verbosity label.
const String kLogLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');

// ============================================================
// === ZONE 2: BOUNDARY VALIDATION & MACHINE SOCKET CONTRACT ===
// ============================================================

/// The injected clock, so "today" is deterministic in tests.
abstract class Clock {
  DateTime now();
}

/// The slice of M1's socket M7 reads through (read_catalog + health).
abstract class CatalogPort {
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope);
  Future<String> healthCheck();
}

/// The slice of M4's socket M7 reads through (read_daily + health).
abstract class DailyViewPort {
  Future<Map<String, dynamic>> handle(Map<String, dynamic> envelope);
  Future<String> healthCheck();
}

/// The Grid Presenter. Read-only; composes view-models.
class M7GridPresenter {
  M7GridPresenter({
    required this.catalog,
    required this.daily,
    required this.clock,
    int? timezoneOffsetMin,
  }) : timezoneOffsetMin = timezoneOffsetMin ?? kDefaultTzOffsetMin;

  final CatalogPort catalog;
  final DailyViewPort daily;
  final Clock clock;
  final int timezoneOffsetMin;

  static const Set<String> _allowedKeys = <String>{
    'view',
    'category_id',
    'book_id',
  };
  static const Set<String> _views = <String>{'home', 'category', 'book'};

  /// THE socket.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input) async {
    for (final String k in input.keys) {
      if (!_allowedKeys.contains(k)) {
        return _fail('E1', 'Unexpected field "$k".', k);
      }
    }
    if (!input.containsKey('view')) {
      return _fail('E1', 'Missing required field "view".', 'view');
    }
    final Object? view = input['view'];
    if (view is! String || !_views.contains(view)) {
      return _fail('E1', 'view must be one of ${_views.toList()}.', 'view');
    }

    String? categoryId;
    String? bookId;
    if (view == 'category') {
      final Object? c = input['category_id'];
      if (c is! String || c.isEmpty) {
        return _fail('E1', 'category_id is required when view=category.', 'category_id');
      }
      categoryId = c;
    }
    if (view == 'book') {
      final Object? b = input['book_id'];
      if (b is! String || b.isEmpty) {
        return _fail('E1', 'book_id is required when view=book.', 'book_id');
      }
      bookId = b;
    }

    // --- read the catalog from M1 -----------------------------------
    Map<String, dynamic> catalogOut;
    try {
      catalogOut = await catalog.handle(<String, dynamic>{
        'op': 'read_catalog',
        'payload': <String, dynamic>{},
        'idempotency_key': null,
        'schema_version': kSchemaVersion,
      });
    } catch (e) {
      return _fail('E4', 'Could not read the catalog: $e');
    }
    if (catalogOut['ok'] != true) {
      final Map<String, dynamic>? err =
          (catalogOut['error'] as Map?)?.cast<String, dynamic>();
      return _fail((err?['code'] as String?) ?? 'E4',
          (err?['message'] as String?) ?? 'The catalog could not be read.');
    }
    final List<dynamic> categories =
        (((catalogOut['data'] as Map)['categories']) as List<dynamic>?) ??
            const <dynamic>[];

    // --- read today's percentages from M4 ---------------------------
    final Map<String, double> pctByBook = <String, double>{};
    try {
      final Map<String, dynamic> dailyOut = await daily.handle(<String, dynamic>{
        'as_of_date': _localToday(),
        'timezone_offset_min': timezoneOffsetMin,
      });
      if (dailyOut['ok'] == true) {
        final List<dynamic> perBook =
            (((dailyOut['data'] as Map)['per_book']) as List<dynamic>?) ??
                const <dynamic>[];
        for (final dynamic e in perBook) {
          final Map<String, dynamic> m = (e as Map).cast<String, dynamic>();
          final Object? id = m['book_id'];
          final Object? pct = m['pct_today'];
          if (id is String && pct is num) {
            pctByBook[id] = pct.toDouble();
          }
        }
      }
    } catch (_) {
      // Percentages are additive: a M4 hiccup must not blank the grid.
      // Every tile simply shows 0% until the next read.
    }

    // --- compose per view -------------------------------------------
    if (view == 'home') {
      final List<Map<String, dynamic>> out = categories
          .map((dynamic c) => _categoryVm((c as Map).cast<String, dynamic>(), pctByBook))
          .toList();
      return _ok(<String, dynamic>{'categories': out});
    }
    if (view == 'category') {
      for (final dynamic c in categories) {
        final Map<String, dynamic> m = (c as Map).cast<String, dynamic>();
        if (m['category_id'] == categoryId) {
          return _ok(_categoryVm(m, pctByBook));
        }
      }
      return _fail('E4', 'category_id does not exist.', 'category_id');
    }
    // view == 'book'
    for (final dynamic c in categories) {
      final List<dynamic> books =
          (((c as Map)['books']) as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic b in books) {
        final Map<String, dynamic> m = (b as Map).cast<String, dynamic>();
        if (m['book_id'] == bookId) {
          return _ok(_bookVm(m, pctByBook));
        }
      }
    }
    return _fail('E4', 'book_id does not exist.', 'book_id');
  }

  // ============================================================
  // === ZONE 3: CONTROL PATH FUNCTIONS (THE SWITCHES) ===
  // ============================================================

  /// C5 companion: the local calendar date, derived from the injected
  /// clock — M7 never calls DateTime.now() directly.
  String _localToday() {
    final DateTime local =
        clock.now().toUtc().add(Duration(minutes: timezoneOffsetMin));
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // === ZONE 4: DATA PATH, FAILURE-SHIELD & HEALTH-PROBE (PIPES) ===
  // ============================================================

  /// D7: one category tile (with its books).
  Map<String, dynamic> _categoryVm(
      Map<String, dynamic> category, Map<String, double> pctByBook) {
    final List<dynamic> books =
        ((category['books']) as List<dynamic>?) ?? const <dynamic>[];
    final List<Map<String, dynamic>> bookVms = books
        .map((dynamic b) => _bookVm((b as Map).cast<String, dynamic>(), pctByBook))
        .toList();
    return <String, dynamic>{
      'category_id': category['category_id'],
      'name': category['name'],
      'book_count': bookVms.length,
      'books': bookVms,
    };
  }

  /// D7: one book tile.
  Map<String, dynamic> _bookVm(
      Map<String, dynamic> book, Map<String, double> pctByBook) {
    final Object? id = book['book_id'];
    return <String, dynamic>{
      'book_id': id,
      'title': book['title'],
      'cover_ref': book['cover_ref'],
      'pct_today': (id is String ? (pctByBook[id] ?? 0.0) : 0.0),
    };
  }

  /// Health probe. Confirms both read seams answer.
  Future<String> healthCheck() async {
    try {
      final String c = await catalog.healthCheck();
      if (c != 'ok') return 'degraded: m1=$c';
      final String d = await daily.healthCheck();
      if (d != 'ok') return 'degraded: m4=$d';
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
    print('[M7] $code: $message');
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
