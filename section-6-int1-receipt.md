# SECTION 6 — REAL EXECUTION RECEIPT (INT-1 v1.0.1)

STATUS: COMPLETE — both defects are fixed, and **every** suite was re-run on Flutter 3.47.7 /
Dart 3.13.5. All seven suites pass: M1, M2, M4, M5, M6, M7 at 5/5 each, and INT-1's
end-to-end suite at 6/6.

```text
$ flutter --version
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (12 days ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (13 days ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0

$ dart run build_runner build
  10s drift_dev on 4 inputs: 1 output; src/modules/m1_library_store.dart
  11s drift_dev on 4 inputs: 2 output; src/modules/m1_library_store.dart
  11s drift_dev on 4 inputs: 1 skipped, 3 output
  0s source_gen:combining_builder on 2 inputs; src/modules/m1_library_store.dart
  0s source_gen:combining_builder on 2 inputs: 1 skipped, 1 output
  Built with build_runner/aot in 141s; wrote 4 outputs.

$ flutter test tests/test_m1_library_store.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m1_library_store.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:01 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:02 +5: All tests passed!

$ flutter test tests/test_m2_book_intake.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m2_book_intake.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:00 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

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
00:01 +5: All tests passed!

$ flutter test tests/test_m7_grid_presenter.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_m7_grid_presenter.dart
00:00 +0: Test 1 — Happy-Path Acceptance
00:01 +1: Test 2 — Boundary & Idempotency Breaker
00:01 +2: Test 3 — Explicit Error-Shape Coverage
00:01 +3: Test 4 — Registry Seam Contract Test
00:01 +4: Test 5 — End-to-End Smoke & Health-Check Probe
00:01 +5: All tests passed!

$ flutter test tests/test_integration_end_to_end.dart
00:00 +0: loading /scratch/work/shelf_app/tests/test_integration_end_to_end.dart
00:00 +0: E2E-1 — Add and see
00:00 +1: E2E-2 — Log and reflect
00:00 +2: E2E-3 — Widget payload
00:01 +3: E2E-4 — Tap routing
00:01 +4: E2E-5 — Backup round-trip
00:01 +5: E2E-6 — The 6x6 wall
00:01 +6: All tests passed!
```

## The two defects — fixed, and how

**DEFECT 1 — ambiguous `Cipher` (M6 adapter).** Fixed exactly as directed: the crypto import
is now `import 'package:cryptography/cryptography.dart' as crypto;`, and every crypto type is
referred to through the prefix (`crypto.AesGcm`, `crypto.SecretKey`, `crypto.SecretBox`,
`crypto.Mac`, `crypto.Hash`, `crypto.Sha256`). M6's own `Cipher` port was NOT renamed — its
contract is untouched.

**DEFECT 2 — `file_picker` API mismatch (M2 adapter).** Fixed, with ONE deliberate deviation
from the letter of the directive, explained below.

The order's Fix 2 suggested:

```dart
final List<PlatformFile> files = await FilePicker.pickFiles(withData: true);
final Uint8List? bytes = f.bytes;
```

That shape does not compile against the pinned `file_picker` 13.1.0 / platform-interface
4.2.0: **`PlatformFile` has no `bytes` field.** Its real API is `name`, `uri`, `path`,
`lengthSync()`, `length()`, `readAsBytes()` and `readAsByteStream()`. The order itself
anticipated this ("Confirm the exact parameter names against the installed 13.1.0 source
before finalising"), so the adapter now uses:

```dart
final PlatformFile? picked = await FilePicker.pickFile(
  type: FileType.custom,
  allowedExtensions: const <String>['pdf', 'epub'],
);
if (picked == null) throw FileAccessDenied('no file selected');
final Uint8List bytes = await picked.readAsBytes();
```

`FilePicker.pickFile()` (singular, returning `PlatformFile?`) and
`FilePicker.pickFiles()` (plural, returning `List<PlatformFile>`) BOTH exist as statics in
13.1.0. The singular form is the better fit here because M2 imports one book at a time, and
`readAsBytes()` is the only way to get the bytes. This was verified by compiling and running
the suite, not assumed.

## Regression result

| Suite | Result |
|---|---|
| `test_m1_library_store` | 5/5 PASS |
| `test_m2_book_intake` | 5/5 PASS |
| `test_m4_daily_engine` | 5/5 PASS |
| `test_m5_widget_bridge` | 5/5 PASS |
| `test_m6_backup_vault` | 5/5 PASS |
| `test_m7_grid_presenter` | 5/5 PASS |
| `test_integration_end_to_end` | 6/6 PASS |

## Note on the build step (matching the order's §6.2)

`build_runner` over the whole project exceeds this sandbox's 2 GB. M1's `.g.dart` was
therefore generated with `build.yaml` narrowed to `src/modules/m1_library_store.dart`, after
which the full `build.yaml` was restored and the suites run. That reproduced the order's own
findings, and it works reliably.

## Still outstanding (not part of this order)

- **M3 Progress Logger was never ordered.** INT-1 still runs on the labelled
  `ProgressLoggerPort` stand-in. The request to issue M3's work order is in
  `M3_ORDER_REQUEST.md`.
- **INT-2's APK was not built** — no Android SDK/Java/Gradle in the builder sandbox. The
  widget sources are delivered; the build and the on-device checks need an Android toolchain.
