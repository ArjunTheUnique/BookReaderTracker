# INT-1 APP SHELL & WIRING v1.0.1 — INDEPENDENT VERIFICATION RECEIPT
Produced by: Chief Architect's sandbox (a **second, independent environment**)
Date: 2026-10-21 · Under test: **INT-1 v1.0.1** plus a full regression of M1, M2, M4, M5, M6, M7

## Why this exists
The previous INT-1 (v1.0) **failed to compile** in an independent environment (two adapter defects). The Builder has since fixed it to v1.0.1. This receipt confirms the fix by **rebuilding the whole project from the repo and running every suite** — not by trusting the report.

## Environment
| Thing | Value |
|---|---|
| Flutter | 3.47.7 (stable) · Dart 3.13.5 |
| OS | Debian 12 (x86_64), 2 GB RAM |
| SQLite | host `libsqlite3.so.0` bridged to `libsqlite3.so` on `LD_LIBRARY_PATH` |
| Codegen note | the full project exceeds 2 GB for `build_runner`; M1's `.g.dart` was generated with `build.yaml` narrowed to `src/modules/m1_library_store.dart`, then the full `build.yaml` was restored before testing |

## The two fixes verified in the delivered code
1. **`Cipher` collision closed.** `m6_backup_vault_adapters.dart` now imports the crypto package with a prefix — `import 'package:cryptography/cryptography.dart' as crypto;` — and refers to `crypto.AesGcm`, `crypto.SecretKey`, `crypto.Sha256`, so M6's own `Cipher` port is unambiguous.
2. **file_picker API corrected.** `m2_book_intake_adapters.dart` now calls `FilePicker.pickFile(...)` — the file_picker **13.x** static method returning a single `PlatformFile?` — instead of the removed 12.x `FilePicker.platform.pickFiles(...)` / `FilePickerResult`.

## Verbatim results
```
batch 1 — test_m1, test_m2, test_m4, test_m5
  00:10 +20: All tests passed!        (20 tests)

batch 2 — test_m6, test_m7, test_integration_end_to_end
  00:03 +9:  All tests passed!        (M6 5 + M7 5 = 10)
  00:13 +16: All tests passed!        (10 + INT-1 e2e 6 = 16)
  E2E-1 — Add and see
  E2E-2 — Log and reflect
  E2E-3 — Widget payload
  E2E-4 — Tap routing
  E2E-5 — Backup round-trip
  E2E-6 — The 6x6 wall
```

**Totals: M1 5/5 · M2 5/5 · M4 5/5 · M5 5/5 · M6 5/5 · M7 5/5 · INT-1 e2e 6/6 — 36 tests, 36 pass, 0 fail.**

## Result
- **INT-1 v1.0.1: PASS** — compiles and passes its end-to-end suite; matches the Builder's receipt.
- **No regression** — all six module suites pass alongside it.
- The app's shell, wiring, seven seams and deep-link routes compile and run.

## Outstanding, honestly
- **M3 Progress Logger was never delivered.** The progress path runs on a clearly-labelled temporary stand-in (`M1ProgressLogger`) declared in `wiring.dart`. E2E-2 passes against that seam. The real module still has to be built and swapped in — the Builder has formally requested the order.
- **INT-2's APK has not been built** — no Android SDK in the sandbox.

## Reproduce it
```
flutter pub get
# narrow build.yaml to src/modules/m1_library_store.dart, then:
dart run build_runner build
# restore the full build.yaml, then:
flutter test tests/test_m1_library_store.dart tests/test_m2_book_intake.dart tests/test_m4_daily_engine.dart tests/test_m5_widget_bridge.dart
flutter test tests/test_m6_backup_vault.dart tests/test_m7_grid_presenter.dart tests/test_integration_end_to_end.dart
```
