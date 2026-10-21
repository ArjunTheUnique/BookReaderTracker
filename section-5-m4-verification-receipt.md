# SECTION 5 — GATE 5B VERIFICATION EXECUTION RECEIPT

STATUS: COMPLETE — the mandated suite was executed and all five M4 tests PASS. M1 was
re-run in the same session to prove no regression.

How this was produced: the builder installed Flutter 3.47.7 (Dart 3.13.5) inside its own
Linux sandbox, built the project with `dart run build_runner build`, and ran the real
`flutter test`. The output below is verbatim.

```text
$ flutter --version
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (11 days ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (12 days ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0

$ dart run build_runner build
  compiling builders/aot
  101s compiling builders/aot
  0s drift_dev on 16 inputs; src/modules/m1_library_store.dart
  8s drift_dev on 16 inputs: 1 output; spent 4s sdk, 3s analyzing; src/modules/m4_daily_engine.dart
  24s drift_dev on 16 inputs: 3 output; spent 15s analyzing, 4s sdk, 3s resolving, 2s reading; tests/test_m4_daily_engine.dart
  25s drift_dev on 16 inputs: 4 skipped, 8 output, 4 no-op
  0s source_gen:combining_builder on 8 inputs; src/modules/m1_library_store.dart
  0s source_gen:combining_builder on 8 inputs: 4 skipped, 1 output, 3 no-op
  Built with build_runner/aot in 131s; wrote 9 outputs.

$ flutter test tests/test_m1_library_store.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it. Please create a new database connection and open that instead.
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_m4_daily_engine.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m4_daily_engine.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Anomaly Breaker
[M4] anomaly: negative pages_today clamped to 0
00:00 +2: Test 3 — Explicit Error-Shape Coverage
[M4] E1: as_of_date must match YYYY-MM-DD.
[M4] E2: timezone_offset_min must be -720..840.
[M4] E4: a required entity is missing
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!
```

## Result

| Test ID & Category | Specific Case / Error Shape | Input Given | Expected Contract Output | Actual Runtime Output | Status |
|---|---|---|---|---|---|
| Test 1 — Happy-Path Acceptance | book A: 50 of 100 pages | log via M1, then M4 for the day | per_book A pages 50, pct 50.0 | `+1` passed | PASS |
| Test 1 — Happy-Path Acceptance | book B: 25 of 50 pages; total | two books, same day | total_pages_today 75; B pct 50.0 | `+1` passed | PASS |
| Test 2 — Boundary & Anomaly | empty day | date with no rows | zeros, SUCCESS (not an error) | `+2` passed | PASS |
| Test 2 — Boundary & Anomaly | backwards clock jump | negative pages_today | clamped to 0, pct 0.0 | `+2` passed | PASS |
| Test 3 — Error-Shape Coverage | **E1** INVALID_INPUT | as_of_date "2026-13-99" | E1 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E2** OUT_OF_RANGE | timezone_offset_min 900 | E2 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E4** NOT_FOUND | M1 reports a missing entity | E4 (passed through) | `+3` passed | PASS |
| Test 4 — Registry Seam Check | OUT keys exactly | data keys | {date, total_pages_today, per_book}; entry {book_id, pages_today, pct_today}; schema_version 1 | `+4` passed | PASS |
| Test 5 — Smoke & Health Probe | M4 boots + seam | healthCheck(); M4 reads M1 | "ok"; total 40 | `+5` passed | PASS |

M4 final line: `00:01 +5: All tests passed!`
M1 regression line: `00:01 +5: All tests passed!`

The `[M1] STORAGE_ERROR` and `[M4] anomaly:` / `[M4] E*` lines are the modules' OWN
expected log lines, printed deliberately by the guard and error-shape cases. They are not
failures.

## Findings surfaced while building

**F1 — M4 is deliberately thin, and that is correct.** M1 already stores the per-day rows,
so M4 reads them and composes the view rather than re-aggregating. Its real work is the
timezone-aware date, the anomaly guard and the payload shaping — exactly as the order's
honest scope note says.

**F2 — the anomaly clamp cannot be exercised through a healthy M1.** M1 already clamps its
own negatives, so a real M1 never hands M4 a negative to clamp. Test 2(b) therefore injects
a fake M1 that returns a negative, proving the guard fires. This is a test-design note, not
a defect: the guard is a genuine safety net for a future M1 change.

**F3 — `DEFAULT_DAILY_GOAL_PAGES` is NOT in the OUT payload (contract tension).** The
order's §7 says M4 "may echo the goal for the widget payload", but §5's OUT shape and §8's
Test 4 require the `data` object to contain EXACTLY `{date, total_pages_today, per_book}`.
Adding the goal would fail Test 4. M4 therefore exposes the goal as the getter
`dailyGoalPages` (and documents it in `.env.example`) without adding a field. If the
Architect wants the goal inside the payload, the registry row for M4 must change first.

**F4 — Dart is nominally typed, so M1 is not automatically M4's `DailySourcePort`.** Same
class of finding as M2's F2. M1 is frozen at v1.0.2, so a one-line adapter wraps it. When
M1 next bumps, declare the port in `shared/contracts.dart` and have M1 implement it.

**F5 — E4 only ever arrives from M1.** M4's input carries no entity reference that could be
"not found", so E4 is a pass-through of M1's own E4. The test drives it with a fake M1.

**F6 — environment.** The build sandbox has 2 GB RAM; a `build_runner` re-run can hit
`Out of Memory`, and one combined test invocation segfaulted once before passing cleanly on
retry. Both are environmental, not code defects — worth knowing for CI sizing.
