# SECTION 5 — GATE 5B VERIFICATION EXECUTION RECEIPT

STATUS: COMPLETE — the mandated suite was executed and all five tests PASS, re-run after
the ADR-013 pin correction.

How this was produced: the builder installed Flutter 3.47.7 (Dart 3.13.5) inside its own
Linux sandbox — the same versions the operator's machine reports — pinned
`sqlite3_flutter_libs` to 0.5.42, built the project, and ran the real `flutter test`. The
output below is verbatim.

```text
$ flutter --version
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (11 days ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (12 days ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0

$ flutter pub get
Resolving dependencies...
Downloading packages...
  build 4.0.11 (5.0.0 available)
  build_config 1.3.3 (1.4.0 available)
  build_runner 2.16.2 (2.17.1 available)
  material_color_utilities 0.13.0 (0.13.1 available)
< sqlite3_flutter_libs 0.5.42 (was 0.6.0+eol) (0.6.0+eol available)
  test_api 0.7.12 (0.7.15 available)
Changed 1 dependency!
6 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

$ grep -A5 "^  sqlite3_flutter_libs:" pubspec.lock
  sqlite3_flutter_libs:
    dependency: "direct main"
    description:
      name: sqlite3_flutter_libs
      sha256: (locked)
      url: "https://pub.dev"
    source: hosted
    version: "0.5.42"

$ dart run build_runner build
  compiling builders/aot
  153s compiling builders/aot
  0s drift_dev on 8 inputs; src/modules/m1_library_store.dart
  5s drift_dev on 8 inputs: 1 output; spent 4s analyzing; tests/test_m1_library_store.dart
  27s drift_dev on 8 inputs: 2 output; spent 20s analyzing, 4s resolving, 2s reading; src/modules/m1_library_store.dart
  28s drift_dev on 8 inputs: 3 output; spent 21s analyzing, 4s resolving, 2s reading; tests/test_m1_library_store.dart
  28s drift_dev on 8 inputs: 2 skipped, 5 output, 1 no-op; spent 21s analyzing, 4s resolving, 2s reading
  0s source_gen:combining_builder on 4 inputs; src/modules/m1_library_store.dart
  0s source_gen:combining_builder on 4 inputs: 2 skipped, 1 output, 1 no-op
  Built with build_runner/aot in 192s; wrote 6 outputs.

$ flutter test tests/test_m1_library_store.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it. Please create a new database connection and open that instead.
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!
```

## Result

| Test ID & Category | Specific Case | Command run | Actual Runtime Output | Status |
|---|---|---|---|---|
| Test 1 — Happy-Path Acceptance | seed 6 categories; add 6 books; update_progress; read back | `flutter test tests/test_m1_library_store.dart` | `+1` … passed | PASS |
| Test 2 — Boundary & Idempotency Breaker | 7th category E3; 7th book E3; repeated key no double-write; Fix C cross-op reuse | `flutter test tests/test_m1_library_store.dart` | `+2` … passed | PASS |
| Test 3 — Explicit Error-Shape Coverage | E1, E2, E3, E4, E5, E7 | `flutter test tests/test_m1_library_store.dart` | `+3` … passed | PASS |
| Test 4 — Registry Seam Contract Test | exact OUT field names/types; schema_version == 1 | `flutter test tests/test_m1_library_store.dart` | `+4` … passed | PASS |
| Test 5 — Smoke & Health-Check Probe | PRAGMA integrity_check == "ok"; 6 empty categories | `flutter test tests/test_m1_library_store.dart` | `+5` … passed | PASS |

Final line: `00:01 +5: All tests passed!`

Note: the line `[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it`
is the module's OWN expected log line, printed deliberately by Test 3's E7 case. It is not
a failure.

## What running the real compiler changed

Building the suite revealed three genuine COMPILE bugs in the module as previously
delivered (all fixed in v1.0.2, Section 1):

1. `part 'm1_library_store.g.dart';` sat ABOVE the imports — invalid Dart.
2. `file_path` / `cover_ref` were typed `Object?` then used as `.isEmpty` — a type error.
3. `_countCategories()` declared `TypedResult` where the query returns `QueryRow`.

None could be seen without compiling — exactly why the order insists on a real receipt.
