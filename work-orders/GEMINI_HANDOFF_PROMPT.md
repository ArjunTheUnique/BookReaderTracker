# HAND-OFF PROMPT — paste this whole file into Gemini

> **How to use it:** attach the four files listed in the "Files you are given" box to your
> Gemini chat, then paste everything below the line. Gemini will produce the corrected
> module, the corrected test, the completed manifest, and the execution receipt — which you
> then bring straight back to the architect for the Gate 5B re-audit.

---

**WHAT TO ATTACH TO GEMINI (4 files):**
1. `section-1-module-code.md` — the M1 module source
2. `section-4-test-script.md` — the M1 test script
3. `section-2-dependency-manifest.md` — the current (incomplete) manifest
4. `section-3-env-example.md` — the `.env.example`

You may also attach `M1_DEFECT_FIX_ORDER_v1.0.md` so Gemini sees the exact audit findings.

---
---

## PROMPT — copy from here down

You are the **Stack Builder Agent** for a Flutter mobile app called "Shelf" (a local-first reading tracker). I am handing you a **DEFECT FIX ORDER** for module **M1 Library Store**. Your job is to apply three fixes, run the real test suite, and return a complete report.

### Context
- Module file path: `src/modules/m1_library_store.dart`
- Test file path: `tests/test_m1_library_store.dart`
- Failed version: **v1.0**  →  target patched version: **v1.0.1**
- Stack: Flutter **3.47.7** (stable), Dart bundled with it, `drift` **2.35.2**, `drift_dev` **2.35.2**, plus `sqlite3_flutter_libs`, `path_provider`, `build_runner`.
- The app is local-first: no server, no accounts, no secrets. All config is non-secret and read via `String.fromEnvironment` / `int.fromEnvironment`.

### The three fixes

**Fix A — complete the pinned dependency manifest.**
In the project root run `flutter pub get`. Then read the resolved versions out of the generated `pubspec.lock` and write them into the manifest with **exact** versions for `sqlite3_flutter_libs`, `path_provider` and `build_runner` (no `^`, no `latest`, no `*`). Every dependency must show one exact version. Keep `drift: 2.35.2` and `drift_dev: 2.35.2` exactly as they are.

**Fix B — run the real suite and capture its output.**
```
dart run build_runner build --delete-conflicting-outputs
flutter test tests/test_m1_library_store.dart
```
Paste the **verbatim terminal output** of the `flutter test` command. Do **not** substitute a Python script, a "parity harness", or a hand-written simulation. The receipt must be the real output of the real Dart test.

**Fix C — harden the idempotency ledger (small, contained).**
The `IdempotencyLedger` table's primary key is currently `{idempotencyKey}`. Change it to the composite key `{op, idempotencyKey}`, and update `_replayIfSeen` and `_rememberKey` to read/write both columns. This makes the replay guard correct even if the same key string is reused across two different operations. Do not change the module's IN/OUT contract or its error codes.

### Rules you must not break
- Do **not** change the IN/OUT contract field names or types.
- Do **not** change the error codes E1–E9, the `schema_version = 1` value, or the 6-category / 6-book caps.
- Do **not** introduce any secret, token or key. Config values only.
- Keep the module cleanly zoned: config / boundary validation / control / data.
- Update the Module Passport header in **both** files to **v1.0.1**.

### If you cannot run Dart/Flutter
If you have **no** code-execution environment with a Dart/Flutter toolchain, you must NOT invent a receipt. Instead: apply Fixes A and C as text, produce the corrected files, and label the receipt section **INCOMPLETE — no Dart toolchain available**, stating plainly that `flutter test` could not be executed. A truthful INCOMPLETE is accepted; a fabricated PASS is not.

### What to return — exactly these six sections, in order

1. **Module ID + Version Stamp** (M1, v1.0.1)
2. **Target Module File Path + Target Test File Path** (as written above)
3. **`.env.example` block** (full contents)
4. **Pinned Dependency Manifest** — the full `pubspec.yaml` dependency block with every exact version, plus the `pubspec.lock` file hash
5. **Full contents** of `src/modules/m1_library_store.dart` and `tests/test_m1_library_store.dart`
6. **The 5-part Verification Execution Receipt** — the real `flutter test` output, one PASS/FAIL line per test:
   - Test 1 — Happy-Path Acceptance
   - Test 2 — Boundary & Idempotency Breaker
   - Test 3 — Explicit Error-Shape Coverage (E1, E2, E3, E4, E5, E7)
   - Test 4 — Registry Seam Contract Test
   - Test 5 — End-to-End Smoke & Health-Check Probe

Return the whole six-section package as one block I can copy back to my architect. No partial returns.

## PROMPT — copy to here
