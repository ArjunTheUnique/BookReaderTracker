# SECTION 1 — TARGET MODULE FILE PATH & PRODUCTION MODULE CODE

Module File: src/modules/m5_widget_bridge.dart | Version: v1.0

```dart
// ============================================================
// MODULE PASSPORT — M5 Widget Bridge
// Version Stamp : v1.0
// Module File   : src/modules/m5_widget_bridge.dart
// Test File     : tests/test_m5_widget_bridge.dart
// Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M5)
// ------------------------------------------------------------
// PLAIN-ENGLISH PURPOSE
//   Build the widget payload from M4's day view, push it to the
//   home-screen widget through the WidgetHost port, and turn a widget
//   tap into a deep-link route back into the app.
//
// MACHINE SOCKET CONTRACT SUMMARY
//   INPUT push : { goal_pages, total_pages_today, per_book_pct[] }
//   INPUT tap  : { target_type, target_id }
//   OUTPUT push success : { ok:true, data:{pushed_at}, schema_version:1 }
//   OUTPUT tap  success : { ok:true, data:{route}, schema_version:1 }
//   OUTPUT failure      : { ok:false, error:{code, message, field?} }
//   ERROR SHAPES : E1 INVALID_INPUT · E7 STORAGE_ERROR ·
//                  E8 PERMISSION_DENIED
//
// CONTROL PATH SUMMARY (the C-switch inside this file)
//   C6 widget tap — map a tap to a deep-link route for the app shell.
//
// DATA PATH SUMMARY (the D-pipe inside this file)
//   D5 widget payload pipe — format the payload and push it through
//      the WidgetHost port to the shared app-group store.
//
// SCOPE NOTE
//   M5 receives the day view from M4; it never reads the database and
//   never computes the day itself. home_widget and the native shells
//   are platform code and cannot run in `flutter test`, so the module
//   talks only to the WidgetHost port.
//
// SAFE TO EDIT BY HAND GUIDE
//   Everything under ZONE 1: kTargetTypes, kWidgetShowTitles,
//   kWidgetRefreshMin, and every log message, plus the deep-link
//   route format in Zone 3.
//
// DO NOT TOUCH WARNING
//   The IN/OUT contract field names and types, the error codes, and
//   the rule that M5 never queries the database.
//
// 2 AM TROUBLESHOOTING HINT
//   On any failure this module returns
//   { ok:false, error:{ code:"E*", message:"...", field? } } and prints
//   "[M5] <CODE>: <detail>". E8 means the OS refused the widget
//   permission — the app keeps working without the widget. E7 means the
//   shared store could not be written; the widget will show "—" until a
//   later push succeeds.
// ============================================================

import 'dart:async';

// ============================================================
// === ZONE 1: SAFE TO EDIT CONFIGURATION & RULES ===
// ============================================================

/// The contract version this module speaks.
const int kSchemaVersion = 1;

/// The only two values a tap's `target_type` may take.
const List<String> kTargetTypes = <String>['book', 'category'];

/// Whether the widget may show book titles. Numbers only by default
/// (privacy, T7).
const bool kWidgetShowTitles =
    bool.fromEnvironment('WIDGET_SHOW_TITLES', defaultValue: false);

/// How often the widget is asked to refresh, in minutes.
const int kWidgetRefreshMin =
    int.fromEnvironment('WIDGET_REFRESH_MIN', defaultValue: 30);

/// Log verbosity label.
const String kLogLevel = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');

// ============================================================
// === ZONE 2: BOUNDARY VALIDATION & MACHINE SOCKET CONTRACT ===
// ============================================================

/// Raised by the platform edge when the shared store cannot be written.
class WidgetHostStorageError implements Exception {
  WidgetHostStorageError([this.message = 'widget store write failed']);
  final String message;
  @override
  String toString() => message;
}

/// Raised by the platform edge when the OS refuses widget permission.
class WidgetHostPermissionDenied implements Exception {
  WidgetHostPermissionDenied([this.message = 'widget permission denied']);
  final String message;
  @override
  String toString() => message;
}

/// The ONLY place M5 touches the platform. The real implementation
/// (home_widget + native shells) lives in the adapter file, so this
/// module never imports the widget plugin.
abstract class WidgetHost {
  /// Write the payload into the shared app-group store the OS widget
  /// reads on its own schedule.
  Future<void> writePayload(Map<String, dynamic> payload);

  /// A liveness probe for the host.
  Future<String> healthCheck();
}

/// The Widget Bridge. Takes a push or a tap request and returns a
/// success or failure map.
class M5WidgetBridge {
  M5WidgetBridge({required this.host});

  final WidgetHost host;

  /// The keys that identify a push request.
  static const Set<String> _pushKeys = <String>{
    'goal_pages',
    'total_pages_today',
    'per_book_pct',
  };

  /// The keys that identify a tap request.
  static const Set<String> _tapKeys = <String>{'target_type', 'target_id'};

  /// Route a request to push or tap by its shape. A request must be one
  /// shape or the other — never both.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> input) async {
    final bool looksTap = input.keys.any(_tapKeys.contains);
    final bool looksPush = input.keys.any(_pushKeys.contains);
    if (looksTap && looksPush) {
      return _fail('E1', 'A request must be a push OR a tap, not both.');
    }
    if (looksTap) return tap(input);
    if (looksPush) return push(input);
    return _fail('E1', 'Unrecognised request shape.');
  }

  /// push — refresh the widget with today's numbers.
  Future<Map<String, dynamic>> push(Map<String, dynamic> input) async {
    for (final String k in input.keys) {
      if (!_pushKeys.contains(k)) {
        return _fail('E1', 'Unexpected field "$k".', k);
      }
    }
    for (final String k in _pushKeys) {
      if (!input.containsKey(k)) {
        return _fail('E1', 'Missing required field "$k".', k);
      }
    }

    final Object? goal = input['goal_pages'];
    if (goal is! int || goal < 0) {
      return _fail('E1', 'goal_pages must be an integer >= 0.', 'goal_pages');
    }
    final Object? total = input['total_pages_today'];
    if (total is! int || total < 0) {
      return _fail('E1', 'total_pages_today must be an integer >= 0.',
          'total_pages_today');
    }
    final Object? pcts = input['per_book_pct'];
    if (pcts is! List) {
      return _fail('E1', 'per_book_pct must be a list.', 'per_book_pct');
    }
    final List<Map<String, dynamic>> outPcts = <Map<String, dynamic>>[];
    for (final dynamic e in pcts) {
      if (e is! Map) {
        return _fail('E1', 'each per_book_pct entry must be an object.',
            'per_book_pct');
      }
      final Map<String, dynamic> m = e.cast<String, dynamic>();
      final Object? id = m['book_id'];
      if (id is! String || id.isEmpty) {
        return _fail('E1', 'per_book_pct.book_id must be a non-empty string.',
            'per_book_pct');
      }
      final Object? pct = m['pct'];
      if (pct is! num) {
        return _fail('E1', 'per_book_pct.pct must be a number.', 'per_book_pct');
      }
      final double pd = pct.toDouble();
      if (pd < 0 || pd > 100) {
        return _fail('E1', 'per_book_pct.pct must be within 0..100.',
            'per_book_pct');
      }
      outPcts.add(<String, dynamic>{'book_id': id, 'pct': pd});
    }

    final String now = DateTime.now().toUtc().toIso8601String();
    // The payload carries an explicit updated_at so the widget can show
    // "—" plus a stamp when it is stale, rather than wrong numbers (S6).
    final Map<String, dynamic> payload = <String, dynamic>{
      'goal_pages': goal,
      'total_pages_today': total,
      'per_book_pct': outPcts,
      'show_titles': kWidgetShowTitles,
      'refresh_min': kWidgetRefreshMin,
      'updated_at': now,
    };

    try {
      await host.writePayload(payload);
    } on WidgetHostPermissionDenied catch (e) {
      return _fail('E8', 'Widget permission refused: ${e.message}');
    } on WidgetHostStorageError catch (e) {
      return _fail('E7', 'Could not write the widget store: ${e.message}');
    } catch (e) {
      return _fail('E7', 'Could not write the widget store: $e');
    }

    return _ok(<String, dynamic>{'pushed_at': now});
  }

  /// tap — turn a widget tap into a deep-link route.
  Future<Map<String, dynamic>> tap(Map<String, dynamic> input) async {
    for (final String k in input.keys) {
      if (!_tapKeys.contains(k)) {
        return _fail('E1', 'Unexpected field "$k".', k);
      }
    }
    for (final String k in _tapKeys) {
      if (!input.containsKey(k)) {
        return _fail('E1', 'Missing required field "$k".', k);
      }
    }
    final Object? tt = input['target_type'];
    if (tt is! String || !kTargetTypes.contains(tt)) {
      return _fail('E1', 'target_type must be one of $kTargetTypes.', 'target_type');
    }
    final Object? tid = input['target_id'];
    if (tid is! String || tid.isEmpty) {
      return _fail('E1', 'target_id must be a non-empty string.', 'target_id');
    }
    return _ok(<String, dynamic>{'route': _routeFor(tt, tid)});
  }

  // ============================================================
  // === ZONE 3: CONTROL PATH FUNCTIONS (THE SWITCHES) ===
  // ============================================================

  /// C6: the deep-link shape the app shell / M7 will open.
  String _routeFor(String targetType, String targetId) =>
      'shelf://$targetType/$targetId';

  // ============================================================
  // === ZONE 4: DATA PATH, FAILURE-SHIELD & HEALTH-PROBE (PIPES) ===
  // ============================================================

  /// Health probe. Confirms the widget host answers.
  Future<String> healthCheck() async {
    try {
      return await host.healthCheck();
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
    print('[M5] $code: $message');
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

## Companion file (platform edge) — src/modules/m5_widget_bridge_adapters.dart

```dart
// ============================================================
// PLATFORM EDGE — M5 Widget Bridge adapters
// Version Stamp : v1.0
// Pairs with    : src/modules/m5_widget_bridge.dart
// ------------------------------------------------------------
// WHY THIS FILE EXISTS
//   M5's logic must not import the widget plugin directly. This is the
//   edge: the only place `home_widget` appears. The module declares the
//   WidgetHost port; this file implements it for a real device.
//
//   It is NOT imported by the module or by the test suite, so the tests
//   stay free of platform plugins. The app shell wires it in at startup.
//
// DO NOT put business rules here — only transport.
// ============================================================

import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'm5_widget_bridge.dart';

/// The real widget edge: writes the payload into the shared app-group
/// store through home_widget, then asks the OS to refresh the widget.
class HomeWidgetHost implements WidgetHost {
  @override
  Future<void> writePayload(Map<String, dynamic> payload) async {
    try {
      await HomeWidget.saveWidgetData<String>(
          'shelf_payload', jsonEncode(payload));
      await HomeWidget.updateWidget(name: 'ShelfWidget');
    } catch (e) {
      final String s = e.toString().toLowerCase();
      // home_widget surfaces permission refusals as a platform error;
      // route those to E8 and everything else to E7.
      if (s.contains('permission') || s.contains('denied')) {
        throw WidgetHostPermissionDenied(s);
      }
      throw WidgetHostStorageError(s);
    }
  }

  @override
  Future<String> healthCheck() async {
    // home_widget has no probe; the module treats this as "host alive".
    return 'ok';
  }
}
```
