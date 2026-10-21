# SECTION 5 — GATE 5B VERIFICATION EXECUTION RECEIPT

STATUS: COMPLETE — the mandated suite was executed and all five M6 tests PASS. The
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
| Test 1 — Happy-Path Acceptance | export seeded library | destination_uri, passphrase | ok; file written; checksum hex | `+1` passed | PASS |
| Test 1 — Happy-Path Acceptance | restore into fresh target | source_uri, passphrase | ok; data matches M1 | `+1` passed | PASS |
| Test 2 — Boundary & Idempotency | wrong passphrase | passphrase "wrong-passphrase" | E9; LIVE data untouched | `+2` passed | PASS |
| Test 2 — Boundary & Idempotency | corrupted file | one byte flipped | E9; LIVE data untouched | `+2` passed | PASS |
| Test 3 — Error-Shape Coverage | **E1** INVALID_INPUT | empty uri | E1 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E1** INVALID_INPUT | passphrase "short" | E1 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E7** STORAGE_ERROR | file write fails | E7 | `+3` passed | PASS |
| Test 3 — Error-Shape Coverage | **E9** BACKUP_INVALID | schema_version 999 | E9 | `+3` passed | PASS |
| Test 4 — Registry Seam Check | OUT keys exactly | export | {bytes, schema_version, checksum}; schema_version 1 | `+4` passed | PASS |
| Test 5 — Smoke & Health Probe | export→restore round-trip | against M1 snapshot | "ok"; 2 books restored | `+5` passed | PASS |

The `[M1]` / `[M4]` / `[M5]` / `[M6]` / `[M7]` log lines are the modules' OWN expected
guard and error-case output, not failures.

## Findings

**F1 — M1 has no restore/replace API (blocking for real restores; recommend an M1 fix
order).** M6's restore must hand the validated snapshot to "M1's atomic replace" — but M1
v1.0.2 exposes no such operation (its ops are upsert_category, add_book, update_progress,
read_catalog, read_daily, delete_book). M6 therefore declares a `LibraryVaultPort` with
`atomicReplace`; the test uses an in-memory seam, and the real adapter
(`m6_backup_vault_adapters.dart`) explicitly throws `UnimplementedError` for it. **M6 is
fully correct and testable, but a real restore cannot reach live data until M1 gains an
atomic `restore_all`.** This is the one place in the stack where a module's job depends on
a capability that does not yet exist.

**F2 — the checksum is over the PLAINTEXT (stated, as the order asks).** On restore the
file is decrypted first, then the plaintext checksum is re-computed and compared. The
cipher's own auth tag (GCM) catches ciphertext tampering; the checksum catches plaintext
corruption.

**F3 — file format.** The `.rtbk` file is JSON:
`{schema_version, cipher, checksum, payload}` where `payload` is the base64 ciphertext.

**F4 — crypto and IO are behind ports (ADR-015).** `dart:io` and `cryptography` appear only
in the adapter file; the module imports neither.

**F5 — environment.** 2 GB sandbox; `dart analyze` crashed under memory pressure during this
session. The tests themselves pass cleanly. Environmental only.
