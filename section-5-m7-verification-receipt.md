# SECTION 5 — GATE 5B VERIFICATION EXECUTION RECEIPT

STATUS: COMPLETE — the mandated suite was executed and all five M7 tests PASS. The
whole stack (M1, M4, M5, M6, M7) was re-run in the same session; every suite is 5/5.

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
  10s drift_dev on 48 inputs: 1 output; src/modules/m4_daily_engine.dart
  18s drift_dev on 48 inputs: 4 output; src/modules/m6_backup_vault.dart
  28s drift_dev on 48 inputs: 8 output; tests/test_m4_daily_engine.dart
  29s drift_dev on 48 inputs: 13 output; src/modules/m4_daily_engine.dart
  29s drift_dev on 48 inputs: 12 skipped, 21 output, 15 no-op
  0s source_gen:combining_builder on 24 inputs; src/modules/m1_library_store.dart
  0s source_gen:combining_builder on 24 inputs: 12 skipped, 1 output, 11 no-op
  Built with build_runner/aot in 157s; wrote 22 outputs.

$ flutter test tests/test_m1_library_store.dart
00:00 +0: loading tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:00 +2: Test 3 — Explicit Error-Shape Coverage
[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it. Please create a new database connection and open that instead.
00:00 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_m4_daily_engine.dart
00:00 +0: loading tests/test_m4_daily_engine.dart
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

$ flutter test tests/test_m5_widget_bridge.dart
00:00 +0: loading tests/test_m5_widget_bridge.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
[M5] E1: goal_pages must be an integer >= 0.
00:00 +2: Test 3 — Explicit Error-Shape Coverage
[M5] E1: target_type must be one of [book, category].
[M5] E7: Could not write the widget store: shared store unwritable
[M5] E8: Widget permission refused: refused
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:00 +5: All tests passed!

$ flutter test tests/test_m6_backup_vault.dart
00:00 +0: loading tests/test_m6_backup_vault.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
[M6] E9: Wrong passphrase or the file is damaged: wrong passphrase
[M6] E9: The backup file is not readable.
00:00 +2: Test 3 — Explicit Error-Shape Coverage
[M6] E1: destination_uri must be a non-empty string.
[M6] E1: passphrase must be at least 8 characters.
[M6] E7: Could not write the backup file: write failed
[M6] E9: Unknown backup schema version.
00:00 +3: Test 4 — Registry Seam Contract Test
00:00 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_m7_grid_presenter.dart
00:00 +0: loading tests/test_m7_grid_presenter.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:01 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
[M7] E1: view must be one of [home, category, book].
[M7] E1: category_id is required when view=category.
[M7] E4: category_id does not exist.
[M7] E4: book_id does not exist.
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!
```

## Result

| Test ID & Category | Specific Case / Error Shape | Input Given | Expected Contract Output | Actual Runtime Output | Status |
|---|---|---|---|---|---|
| Test 1 — Happy-Path Acceptance | home view with 1 book read | 50 of 100 pages | 6 categories; book_count 1; pct_today 50.0 | `+1` passed | PASS |
| Test 2 — Boundary & Idempotency | empty catalog | fresh library | 6 empty tiles, SUCCESS | `+2` passed | PASS |
| Test 2 — Boundary & Idempotency | full category | 6 books added | book_count 6 | `+2` passed | PASS |
| Test 3 — Error-Shape Coverage | **E1** INVALID_INPUT | view "shelf" | E1 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E1** INVALID_INPUT | view category, no id | E1 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E4** NOT_FOUND | category_id "ghost" | E4 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E4** NOT_FOUND | book_id "ghost" | E4 | `+3` passed | PASS |
| Test 4 — Registry Seam Check | OUT keys exactly | home / category / book | {categories}; category & book key sets; schema_version 1 | `+4` passed | PASS |
| Test 5 — Smoke & Health Probe | all three views | home, category, book | "ok"; book pct 30.0 | `+5` passed | PASS |

The `[M1]` / `[M4]` / `[M5]` / `[M6]` / `[M7]` log lines are the modules' OWN expected
guard and error-case output, not failures.

## Findings

**F1 — M7 must derive "today" to ask M4, but its input carries no date.** The order says
M7 reads percentages "from M4", and M4's socket requires `{as_of_date, timezone_offset_min}`
— yet M7's input is only `{view, category_id?, book_id?}`. M7 therefore injects a `Clock`
and a `DEFAULT_TZ_OFFSET_MIN` tunable so it can compute the local date and call M4. This is
a necessary design addition; if the Architect prefers M7 to receive the date, the registry
row for M7 must change.

**F2 — M7 depends on M1 and M4 through two ports** (`CatalogPort`, `DailyViewPort`), with
one-line adapters, because Dart is nominally typed and M1/M4 are frozen.

**F3 — duplicated port interfaces caused a real compile error (recommend shared/contracts).**
M4 and M7 each declare their own `Clock` (and M4 declares `DailySourcePort` while M7
declares `DailyViewPort`). Because the test imports both files, `Clock` was ambiguous and
the suite failed to compile until import prefixes were added. The fix is architectural: move
`Clock` and the socket interfaces into `shared/contracts.dart`, which the Master Doc's
folder tree already reserves for exactly this.

**F4 — M7 is read-only.** It calls M1 `read_catalog` and M4 for percentages; it never writes
and never computes a percentage itself, as required.

**F5 — environment.** 2 GB sandbox; `dart analyze` crashed under memory pressure this
session. The tests pass cleanly. Environmental only.
