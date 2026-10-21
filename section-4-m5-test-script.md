# SECTION 4 — TARGET TEST FILE PATH & RUNNABLE 5-PART VERIFICATION SCRIPT

Test File: tests/test_m5_widget_bridge.dart | Target Module: src/modules/m5_widget_bridge.dart

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

## Run it

1. `flutter pub get`  2. ensure `build.yaml` exists  3. `dart run build_runner build` then `flutter test tests/test_m5_widget_bridge.dart`.
