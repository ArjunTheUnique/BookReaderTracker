# SECTION 6 — 5-PART VERIFICATION EXECUTION RECEIPT

STATUS: COMPLETE — all five M3 tests pass on Flutter 3.47.7 / Dart 3.13.5. The whole stack
was re-run in the same session: **M1, M2, M3, M4, M5, M6, M7 at 5/5 each**, and INT-1's
end-to-end suite at **6/6**.

```text
$ flutter --version
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (13 days ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (13 days ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0

$ dart run build_runner build
  0s source_gen:combining_builder on 2 inputs; src/modules/m1_library_store.dart
  0s source_gen:combining_builder on 2 inputs: 1 skipped, 1 output
  Built with build_runner/aot in 117s; wrote 4 outputs.

$ flutter test tests/test_m1_library_store.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_m2_book_intake.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m2_book_intake.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:00 +5: All tests passed!

$ flutter test tests/test_m3_progress_logger.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m3_progress_logger.dart
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
00:00 +5: E2E-6 — The 6x6 wall
00:01 +6: All tests passed!
```

## Result

| Test ID & Category | Specific Case / Error Shape | Input Given | Expected Contract Output | Actual Runtime Output | Status |
|---|---|---|---|---|---|
| Test 1 — Happy-Path Acceptance | valid progress on an existing book | page 40 of 100 | ok; pct_read 40.0; saved true; row in M1 | `+1` passed | PASS |
| Test 2 — Boundary & Idempotency | page outside the book | page 200 of 100 | E2 | `+2` passed | PASS |
| Test 2 — Boundary & Idempotency | the same logical save twice | derived key | one row; second `saved:false` | `+2` passed | PASS |
| Test 3 — Error-Shape Coverage | **E1** INVALID_INPUT | page `"forty"` / bad date / future date | E1 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E2** OUT_OF_RANGE | page 999 | E2 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E4** NOT_FOUND | unknown book_id | E4 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E5** DUPLICATE | store reports a duplicate | E5 passed through | `+3` passed | PASS |
| Test 4 — Registry Seam Check | OUT keys exactly | valid save | `{book_id, current_page, pct_read, saved}`; schema_version 1 | `+4` passed | PASS |
| Test 5 — Smoke & Health Probe | boots; M3→M1 seam | healthCheck() | "ok"; 25 pages, not doubled | `+5` passed | PASS |

The `[M3] E1: …` lines are the module's own deliberate error-case output, not failures.

## Findings

**F1 — E5 has no reachable trigger through M1's `update_progress`.** The order defines E5 as
"a genuine duplicate — passed through from M1 unchanged". But M1 v1.0.2 emits E5 only from
`add_book` ("book_id already exists"); its `update_progress` never does. A repeated
idempotency key is caught earlier by M1's ledger and returns `saved:false` — which the order
itself says is NOT an error. So M3 implements the E5 **passthrough faithfully**, and Test 3
proves it with a stub store that returns E5. The passthrough is a contract guarantee; it is
not a runtime path through the current M1.

**F2 — the idempotency-key rule in the order is internally inconsistent, and I resolved it.**
The input contract says `idempotency_key` is REQUIRED and an empty key is E1 — yet the design
requirement says M3 must DERIVE a stable key from the logical save, and Test 2 speaks of "the
same derived key". Resolution implemented: **absent → M3 derives** (`m3:<fnv1a32 of
book_id|read_on|page>`); **present but empty or not a string → E1**; **present and non-empty →
passed through unchanged**. This satisfies both statements and makes Test 2's derivation real.

**F3 — the order mandates an injected Clock but does not say what it is for.** `read_on` is an
input field, so the clock is not needed to date the save. I gave it a real job: a `read_on`
later than the clock's "today" is rejected with E1 (a future reading date is not a real save).
If the Architect intended a different use, this is the one behaviour to redirect.

**F4 — M1's `read_daily` accepts only `{as_of_date}`.** The timezone offset belongs to M4,
which resolves "today" before calling M1. My first test draft passed the offset through to
M1 and got E1; the test now calls M1 with `as_of_date` only. Not a defect — a contract detail
worth recording so it is not re-learned.

**F5 — `Clock` is now declared independently by M3, M4 and M7.** Three separate interface
types for the same idea. This reinforces M7's F3 and INT-1's F3: move `Clock` (and the socket
ports) into `shared/contracts.dart` so the wiring does not have to implement several of them.

## Still outstanding

- **INT-1's wiring still uses the temporary `M1ProgressLogger` stand-in.** Now that M3 exists,
  that one line in `src/app/wiring.dart` can be swapped for the real module. It is a change to
  INT-1, so it is not part of this M3 order — say the word and it is a two-minute follow-up.
- **INT-2's APK was not built** — no Android SDK in the builder sandbox.
