# SECTION 5 — GATE 5B VERIFICATION EXECUTION RECEIPT

STATUS: COMPLETE — the mandated suite was executed and all five M2 tests PASS. M1 was
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
  170s compiling builders/aot
  0s drift_dev on 20 inputs; src/modules/m1_library_store.dart
  5s drift_dev on 20 inputs: 1 output; spent 3s analyzing; src/modules/m2_book_intake.dart
  38s drift_dev on 20 inputs: 3 output; spent 30s analyzing; tests/test_m1_library_store.dart
  46s drift_dev on 20 inputs: 4 output; spent 36s analyzing; tests/test_m2_book_intake.dart
  47s drift_dev on 20 inputs: 6 output; spent 37s analyzing; src/modules/m2_book_intake.dart
  48s drift_dev on 20 inputs: 5 skipped, 10 output, 5 no-op
  0s source_gen:combining_builder on 10 inputs; src/modules/m1_library_store.dart
  0s source_gen:combining_builder on 10 inputs: 5 skipped, 1 output, 4 no-op
  Built with build_runner/aot in 226s; wrote 11 outputs.

$ flutter test tests/test_m1_library_store.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:01 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it. Please create a new database connection and open that instead.
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:02 +5: All tests passed!

$ flutter test tests/test_m2_book_intake.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m2_book_intake.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
[M2] E3: Category already holds 6 books.
[M2] E6: File is larger than the 1 MB import cap.
00:01 +2: Test 3 — Explicit Error-Shape Coverage
[M2] E1: title must be 1-200 characters.
[M2] E2: total_pages must be 1-20000.
[M2] E3: Category already holds 6 books.
[M2] E4: category_id does not exist.
[M2] E6: Only .pdf, .epub files are supported.
[M2] E7: Copy to app storage failed: disk full
[M2] E8: Permission to read the file was refused: user refused
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!
```

## Result

| Test ID & Category | Specific Case / Error Shape | Input Given | Expected Contract Output | Actual Runtime Output | Status |
|---|---|---|---|---|---|
| Test 1 — Happy-Path Acceptance | manual book (valid) | source=manual, total_pages=120 | ok; total_pages 120; source manual | `+1` passed | PASS |
| Test 1 — Happy-Path Acceptance | device file (valid) | source=device_file, .pdf via fake port | ok; EXTRACTED total_pages=42 | `+1` passed | PASS |
| Test 2 — Boundary & Idempotency | 7th book in a full category | 6 books then one more | E3 (from M1) | `+2` passed | PASS |
| Test 2 — Boundary & Idempotency | file over MAX_IMPORT_MB | 1 MB cap, 1 MB+1 bytes | E6 | `+2` passed | PASS |
| Test 2 — Boundary & Idempotency | repeated idempotency_key | same key twice | added once, not twice | `+2` passed | PASS |
| Test 3 — Error-Shape Coverage | **E1** INVALID_INPUT | title 201 chars | E1 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E2** OUT_OF_RANGE | manual total_pages=0 | E2 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E3** LIMIT_EXCEEDED | 7th book | E3 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E4** NOT_FOUND | category_id=ghost | E4 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E6** UNSUPPORTED_FORMAT | .txt file | E6 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E7** STORAGE_ERROR | copy fails | E7 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E8** PERMISSION_DENIED | port refuses | E8 | `+3` passed | PASS |
| Test 4 — Registry Seam Check | OUT keys exactly | data keys | {book_id, category_id, total_pages, source}; schema_version 1 | `+4` passed | PASS |
| Test 5 — Smoke & Health Probe | M2 boots + seam | healthCheck() | "ok"; M2→M1 add works | `+5` passed | PASS |

M2 final line: `00:01 +5: All tests passed!`
M1 regression line: `00:02 +5: All tests passed!`

The `[M1] STORAGE_ERROR` and `[M2] E*` lines are the modules' OWN expected log lines,
printed deliberately by the error-shape cases. They are not failures.

## Findings surfaced while building (please read)

**F1 — pdfx is a Flutter plugin and CANNOT run inside `flutter test`.** Proved empirically:
calling pdfx in a test fails with `FlutterError: Binding has not yet been initialized`. So
extraction cannot be called directly from a unit test. M2 therefore puts page-count
extraction behind an injectable `PageExtractor` port (real implementation uses pdfx/epubx;
tests inject a fake). This extends the order's FileAccess-port principle to the parser, and
is the only reason the suite can run at all. epubx is pure Dart and would run fine.

**F2 — Dart is nominally typed, so M1 is not automatically M2's `LibraryStorePort`.** M1 is
frozen at v1.0.2 and must not be changed by an M2 order, so M2 declares a `LibraryStorePort`
interface and a one-line adapter wraps M1. Recommendation: when M1 next has a version bump,
declare the port in `shared/contracts.dart` and have M1 implement it — then the adapter
disappears.

**F3 — M1's `add_book` replay is fragile (recommend an M1 fix order).** M1's idempotency
ledger recognises a repeated key, but the replay path then looks the book up by the
`book_id` in the *incoming payload*. If a caller retries with a different `book_id`, M1
returns **E4** instead of the original success — even though its own contract says a
repeated key "returns success". M2 works around this by deriving a **stable** `book_id` from
the idempotency key, so a retry re-sends the same id. That makes M2 correct, but the
underlying M1 behaviour should be fixed: the ledger should return the original book.

**F4 — sandbox memory.** The build sandbox has 2 GB RAM; a `build_runner` re-run can hit
`Out of Memory` when re-analysing the generated `.g.dart`. A clean build succeeds. This is
environmental, not a code defect, but worth knowing for CI sizing.
