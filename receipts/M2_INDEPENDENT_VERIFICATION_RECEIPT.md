# M2 BOOK INTAKE — INDEPENDENT VERIFICATION RECEIPT
Produced by: Chief Architect's sandbox (a **second, independent environment**)
Date: 2026-10-19 · Modules under test: **M2 Book Intake v1.0** (and M1 Library Store v1.0.2, regression)

## Why this exists
The operator's machine is never used. The Stack Builder verified M2 in its own sandbox; this is a **second, independent run** by the Architect, confirming the Builder's result is real and reproducible.

## Environment
| Thing | Value |
|---|---|
| Flutter | 3.47.7 (stable) |
| Dart | 3.13.5 |
| OS | Debian 12 (x86_64) |
| SQLite | host `libsqlite3.so.0` bridged to `libsqlite3.so` on `LD_LIBRARY_PATH` |

## Method (reproducible from the delivered artifacts alone)
1. Built a fresh `shelf_app/` from the delivered files only: `m1_library_store.dart`, `m2_book_intake.dart`, `m2_book_intake_adapters.dart`, both test files, `build.yaml`, and the pinned `pubspec.yaml`.
2. `flutter pub get` → 113 dependencies resolved.
3. `dart run build_runner build` → generated `src/modules/m1_library_store.g.dart` (86,777 bytes).
4. `flutter test` on each suite.

## Verbatim output
```text
=== M1 (regression) ===
00:00 +0: Test 1 — Happy-Path Acceptance
00:01 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it. Please create a new database connection and open that instead.
00:02 +3: Test 4 — Registry Seam Contract Test
00:02 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:02 +5: All tests passed!

=== M2 (new) ===
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
[M2] E3: Category already holds 6 books.
[M2] E6: File is larger than the 1 MB import cap.
00:00 +2: Test 3 — Explicit Error-Shape Coverage
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
- **M2 v1.0: 5 / 5 PASS** — matches the Builder's receipt line-for-line.
- **M1 v1.0.2 regression: 5 / 5 PASS** — no regression introduced by M2.
- The `[M1]` and `[M2]` log lines are the modules' own deliberate error-case output, not failures.

## What this proves
- M2 v1.0 compiles and passes in a **second, independent environment** — the Gate 5B PASS is reproducible.
- M1 remains green with M2 present — the seam is intact.
- The operator's machine is not required at any point.

## Reproduce it
```
flutter pub get
dart run build_runner build
flutter test --reporter expanded tests/test_m1_library_store.dart
flutter test --reporter expanded tests/test_m2_book_intake.dart
```
On a host with only `libsqlite3.so.0`, symlink it to `libsqlite3.so` and add that directory to `LD_LIBRARY_PATH`.
