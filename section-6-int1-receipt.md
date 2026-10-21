# SECTION 6 — REAL EXECUTION RECEIPT

STATUS: COMPLETE — the whole stack was executed on Flutter 3.47.7 / Dart 3.13.5 in the
builder's sandbox. **All seven suites pass**: M1–M7 (5/5 each) and INT-1's end-to-end suite
(6/6).

```text
$ flutter test tests/test_m1_library_store.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_m2_book_intake.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m2_book_intake.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_m4_daily_engine.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m4_daily_engine.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Anomaly Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:00 +5: All tests passed!

$ flutter test tests/test_m5_widget_bridge.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m5_widget_bridge.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:00 +5: All tests passed!

$ flutter test tests/test_m6_backup_vault.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m6_backup_vault.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:00 +5: All tests passed!

$ flutter test tests/test_m7_grid_presenter.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m7_grid_presenter.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_integration_end_to_end.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_integration_end_to_end.dart
00:00 +0: E2E-1 — Add and see
00:00 +1: E2E-2 — Log and reflect
00:00 +2: E2E-3 — Widget payload
00:00 +3: E2E-4 — Tap routing
00:00 +4: E2E-5 — Backup round-trip
00:01 +5: E2E-6 — The 6x6 wall
00:01 +6: All tests passed!
```

## Result

| Test | What it proves | Status |
|---|---|---|
| E2E-1 — Add and see | a book added via M2 appears in the right M7 home tile | PASS |
| E2E-2 — Log and reflect | progress logged via the M3 seam shows in M4's day view AND on the book tile | PASS |
| E2E-3 — Widget payload | M4 day view + shell goal accepted by M5; the fake host received goal_pages, total_pages_today, per_book_pct | PASS |
| E2E-4 — Tap routing | `shelf://book/<id>` and `shelf://category/<id>` resolve to the right screen | PASS |
| E2E-5 — Backup round-trip | M6 export → wipe → restore → the grid is identical | PASS |
| E2E-6 — The 6x6 wall | a 7th book and a 7th category both fail with E3 | PASS |
| M1–M7 regression | every module suite still 5/5 | PASS |

## Findings

**F1 — M3 has not been delivered, so INT-1 wires a temporary seam.** The Progress Logger
module (M3) has never been issued to the builder, yet INT-1's wiring table and the shell's
"log progress" action both need it. `wiring.dart` therefore declares a `ProgressLoggerPort`
and a clearly-labelled `M1ProgressLogger` stand-in that logs straight through M1's
`update_progress` in M3's shape. E2E-2 exercises that seam. When M3's module arrives it
replaces the stand-in; nothing else changes.

**F2 — the adapter files had latent compile errors that only integration could reveal.**
`m2_book_intake_adapters.dart` and `m6_backup_vault_adapters.dart` are not imported by their
own module tests (those use fakes), so they had never been compiled. `wiring.dart` is the
first thing to import them, and it surfaced three real errors:
  - `file_picker` 13 uses a **static** `FilePicker.pickFile()` returning a `PlatformFile`
    with `readAsBytes()` — there is no `FilePicker.platform` / `.bytes` (the module was
    written against the older API). Fixed.
  - the `cryptography` package also exports a class named **`Cipher`**, which collided with
    M6's own `Cipher` port. The crypto import is now prefixed. Fixed.
  - `wiring.dart`'s `grid` import prefix was shadowed by its own `grid` field. Fixed.
  **Recommendation:** every module's adapter file should be compiled by that module's own
  suite (a tiny import/smoke test), so these errors surface at the module gate, not at
  integration.

**F3 — M4 and M7 each declare their own `Clock` / socket ports.** They are separate types,
so the wiring must implement both and use import prefixes. This is the same class of finding
as M7's F3: move `Clock` and the socket interfaces into `shared/contracts.dart`.

**F4 — `goal_pages` wiring (resolves M4 finding F3).** The shell reads the daily goal from
settings and passes it to M5; M4 supplies only `total_pages_today` and `per_book`. E2E-3
proves this end to end.

**F5 — `flutter create` side-effect.** Scaffolding the Android platform for INT-2 added a
default `test/widget_test.dart` that references the template app; it must be deleted, or a
bare `flutter test` (no path) will fail on it.
