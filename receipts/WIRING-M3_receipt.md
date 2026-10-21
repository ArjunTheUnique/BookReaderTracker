# RECEIPT — WIRING-M3

**Status: DELIVERED** · 2026-10-21 · Project: Reading Tracker ("Shelf")
Order: `work-orders/WIRING_SWAP_M3.md` · Version Stamp: **INT-1 v1.0.2**

## What changed

**File:** `src/app/wiring.dart`

- Added `M3ProgressLoggerAdapter implements ProgressLoggerPort` — delegates `handle` / `healthCheck` to the real `m3.M3ProgressLogger`.
- Added `M1ProgressStorePort implements m3.ProgressStorePort` — the one-line bridge from M3's own M1 seam to the frozen M1.
- `SystemClock` now implements `engine.Clock`, `m7grid.Clock` **and** `m3.Clock` — three separate Clock types (INT-1 finding F3 / M3 finding F5).
- **Deleted** the temporary `M1ProgressLogger` stand-in and its "M3 NOTE" comments.
- Both call sites — `production()` and `forTest()` — now construct the real module.

`ProgressLoggerPort` is kept: the shell still uses the seam. M3's module and its tests are untouched; no other module changed.

## Definition of done

- `src/app/wiring.dart` compiles, and `grep -rn "M1ProgressLogger" src/` returns **nothing** — the stand-in is gone.
- Verbatim execution below.

## Verbatim execution (Flutter 3.47.7 / Dart 3.13.5)

```text
$ flutter --version
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (13 days ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (13 days ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0

$ dart run build_runner build
  0s source_gen:combining_builder on 2 inputs; src/modules/m1_library_store.dart
  0s source_gen:combining_builder on 2 inputs: 1 skipped, 1 output
  Built with build_runner/aot in 131s; wrote 4 outputs.

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

$ flutter test tests/test_m3_progress_logger.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m3_progress_logger.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:00 +5: All tests passed!

$ flutter test tests/test_m4_daily_engine.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m4_daily_engine.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Anomaly Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

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
00:01 +2: Test 3 — Explicit Error-Shape Coverage
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
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

| Suite | Result |
|---|---|
| `tests/test_m3_progress_logger.dart` | **5/5 PASS** |
| `tests/test_integration_end_to_end.dart` | **6/6 PASS** |
| regression — M1, M2, M4, M5, M6, M7 | 5/5 each PASS |
