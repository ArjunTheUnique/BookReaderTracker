# M4 DAILY ENGINE — INDEPENDENT VERIFICATION RECEIPT
Produced by: Chief Architect's sandbox (a **second, independent environment**)
Date: 2026-10-20 · Modules under test: **M4 Daily Engine v1.0** (and M1 Library Store v1.0.2, regression)

## Why this exists
The operator's machine is never used. The Stack Builder verified M4 in its own sandbox; this is a **second, independent run** by the Architect, confirming the Builder's result is reproducible.

## Environment
| Thing | Value |
|---|---|
| Flutter | 3.47.7 (stable) — re-provisioned fresh this session |
| Dart | 3.13.5 |
| OS | Debian 12 (x86_64) |
| SQLite | host `libsqlite3.so.0` bridged to `libsqlite3.so` on `LD_LIBRARY_PATH` |

## Method (reproducible from the delivered artifacts alone)
1. Built a fresh `shelf_app/` from the delivered files only: `m1_library_store.dart`, `m4_daily_engine.dart`, both test files, `build.yaml`, and the pinned `pubspec.yaml`.
2. `flutter pub get` → 89 dependencies resolved.
3. `dart run build_runner build` → generated `src/modules/m1_library_store.g.dart` (86,777 bytes).
4. `flutter test` on each suite.

## Verbatim output
```text
=== M1 (regression) ===
00:00 +0: Test 1 — Happy-Path Acceptance
00:01 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it. Please create a new database connection and open that instead.
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

=== M4 (new) ===
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Anomaly Breaker
[M4] anomaly: negative pages_today clamped to 0
00:00 +2: Test 3 — Explicit Error-Shape Coverage
[M4] E1: as_of_date must match YYYY-MM-DD.
[M4] E2: timezone_offset_min must be -720..840.
[M4] E4: a required entity is missing
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!
```

## Result
- **M4 v1.0: 5 / 5 PASS** — matches the Builder's receipt line-for-line.
- **M1 v1.0.2 regression: 5 / 5 PASS** — no regression introduced by M4.
- The `[M1]` and `[M4]` log lines are the modules' own deliberate guard/error-case output, not failures.

## Cost note (honest)
The sandbox is recycled between sessions, so each independent re-run requires re-provisioning the Flutter toolchain (~6 minutes of downloads/extract/codegen). **Recommendation: batch future independent re-runs** — provision once, then run every pending module's suite in the same session — to amortise that cost.

## Reproduce it
```
flutter pub get
dart run build_runner build
flutter test --reporter expanded tests/test_m1_library_store.dart
flutter test --reporter expanded tests/test_m4_daily_engine.dart
```
