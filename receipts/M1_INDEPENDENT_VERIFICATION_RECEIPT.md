# M1 LIBRARY STORE — INDEPENDENT VERIFICATION RECEIPT
Produced by: Chief Architect's sandbox (a **second, independent environment** — not the operator's machine, not the Stack Builder's sandbox)
Date: 2026-10-19  ·  Module under test: M1 Library Store, Version Stamp **v1.0.2**

## Why this exists
The operator's machine is never used. The Stack Builder verified M1 in its own sandbox. This receipt is a **second, independent run** by the Architect, to confirm the Builder's result was real and reproducible — not a one-off.

## Environment
| Thing | Value |
|---|---|
| Flutter | 3.47.7 (stable) |
| Dart | 3.13.5 |
| OS | Debian 12 (x86_64) |
| SQLite | host `libsqlite3.so.0`, bridged to the `libsqlite3.so` name the Dart `sqlite3` package expects |

## Method (reproducible from the delivered artifacts alone)
1. Built a fresh project `shelf_app/` from the **delivered v1.0.2 files only**: `m1_library_store.dart`, `test_m1_library_store.dart`, `build.yaml`, and the pinned manifest.
2. `flutter pub get`
3. `dart run build_runner build` → generated `src/modules/m1_library_store.g.dart` (86,777 bytes)
4. `flutter test --reporter expanded tests/test_m1_library_store.dart`

## Verbatim output
```text
00:00 +0: loading /scratch/work/verify/shelf_app/tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:01 +1: Test 2 — Boundary & Idempotency Breaker
00:02 +2: Test 3 — Explicit Error-Shape Coverage
[M1] STORAGE_ERROR: Bad state: Can't re-open a database after closing it. Please create a new database connection and open that instead.
00:02 +3: Test 4 — Registry Seam Contract Test
00:02 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:02 +5: All tests passed!
```

## Result
**5 / 5 PASS.** This matches the Stack Builder's receipt line-for-line, including the single `[M1] STORAGE_ERROR` line — which is Test 3's *intended* E7 case (it closes the database and then calls `read_catalog` on purpose), not a failure.

## What this proves
- M1 v1.0.2 compiles and its five-test suite passes **in a second, independent environment**.
- The Gate 5B PASS for M1 is **reproducible**, not environment-specific.
- **The operator's machine is not required at any point** — verification can run entirely in cloud sandboxes.
- Going forward, every module's return package can be **independently re-run** by the Architect, giving two independent verifiers per module.

## Reproduce it yourself (any machine with Flutter 3.47.7)
```
flutter pub get
dart run build_runner build
flutter test --reporter expanded tests/test_m1_library_store.dart
```
On a host where only `libsqlite3.so.0` is present, symlink it to `libsqlite3.so` and put that directory on `LD_LIBRARY_PATH` first.
