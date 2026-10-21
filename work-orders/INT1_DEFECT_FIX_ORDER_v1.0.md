# DEFECT FIX ORDER — INT-1 App Shell & Wiring
**Failed Version Stamp: v1.0 → Target Patched Version Stamp: v1.0.1**
Issued at Gate 5B · Date 2026-10-21 · Project: Reading Tracker ("Shelf")

INT-1 was **independently re-run in a second environment** and **fails to compile**. The Builder's receipt reported the end-to-end suite passing; in a clean environment it does not build. Two genuine defects, both in the **adapter files** — which the module unit tests never compile, which is why they stayed hidden until the integration step. Fully self-contained.

---

## 1. Identity

| Field | Value |
|---|---|
| Order ID | INT-1 |
| Failed Version Stamp | v1.0 |
| Target Patched Version Stamp | v1.0.1 |
| Files to change | `src/modules/m6_backup_vault_adapters.dart`, `src/modules/m2_book_intake_adapters.dart` |
| Module code | unchanged (M5, M6, M7 all pass 5/5 independently) |

---

## 2. Exact failed items

**DEFECT 1 — ambiguous `Cipher` (compile error).**
`m6_backup_vault.dart` declares its own port `abstract class Cipher`. `m6_backup_vault_adapters.dart` imports **both** `package:cryptography/cryptography.dart` (which also exports a `Cipher`) and `m6_backup_vault.dart`. The name `Cipher` is therefore ambiguous, and `wiring.dart:197` fails: *"The argument type 'CryptographyCipher' can't be assigned to the parameter type 'Cipher'."*

**DEFECT 2 — `file_picker` API mismatch (compile errors).**
`m2_book_intake_adapters.dart` uses an API that file_picker **13.1.0** does not have:
- `FilePickerResult` — **not a type** in 13.1.0.
- `FilePicker.platform.pickFiles(...)` — **not found**; in 13.1.0 `pickFiles` is a **static** method.
- `PlatformFile.bytes` — not defined on the 4.2.0 platform interface as used.

---

## 3. Expected vs Actual

| Item | Expected | Actual | Delta |
|---|---|---|---|
| `flutter test tests/test_integration_end_to_end.dart` | compiles; E2E-1…6 pass | **compilation failed** | does not build |
| `Cipher` in the M6 adapter | unambiguous | ambiguous (module port vs crypto package) | compile error |
| file_picker call | valid for 13.1.0 | uses the pre-13 API | compile error |

---

## 4. Root-cause diagnosis

Both defects are **version/namespace mismatches inside the adapter files**:
- The M6 adapter imports the crypto package unqualified, colliding with the module's own `Cipher` port.
- The M2 adapter was written against an **older file_picker API** than the pinned `13.1.0`.

Neither is a design fault in M5/M6/M7 — their contracts and tests are sound. Both were invisible to the module suites because **no module test imports the adapters**; only INT-1's wiring does.

---

## 5. Corrected specification & exact fix directive

**Fix 1 — prefix the crypto import in the M6 adapter.**
```
// in src/modules/m6_backup_vault_adapters.dart
import 'package:cryptography/cryptography.dart' as crypto;
```
Then refer to the crypto types through the prefix (e.g. `crypto.Cipher` where the package type is meant), so the module's own `Cipher` port stays unambiguous. **Do not rename the module's `Cipher` port** — that would change M6's contract.

**Fix 2 — use the file_picker 13.1.0 API in the M2 adapter.**
In 13.1.0 `pickFiles` is a static method returning `Future<List<PlatformFile>>` (not a `FilePickerResult?`). Replace:
```dart
final FilePickerResult? result =
    await FilePicker.platform.pickFiles(withData: true);
if (result == null || result.files.isEmpty) { throw FileAccessDenied('no file selected'); }
final PlatformFile f = result.files.first;
```
with:
```dart
final List<PlatformFile> files = await FilePicker.pickFiles(withData: true);
if (files.isEmpty) { throw FileAccessDenied('no file selected'); }
final PlatformFile f = files.first;
final Uint8List? bytes = f.bytes;
if (bytes == null) { throw FileAccessDenied('file bytes unavailable (permission?)'); }
```
(Confirm the exact parameter names against the installed 13.1.0 source before finalising.)

**Do not change** any module's IN/OUT contract, any error code, or the port definitions.

---

## 6. Full regression re-run mandate

After the two fixes:
1. Re-run **every** suite and return the real `flutter test` output: `test_m1`, `test_m4`, `test_m5`, `test_m6`, `test_m7`, and **`test_integration_end_to_end`** (all six E2E cases).
2. Note: `build_runner` on the full project exceeds a 2 GB sandbox — generate M1's `.g.dart` in isolation (narrow `build.yaml` to `src/modules/m1_library_store.dart`), then restore the full `build.yaml` and run the tests. That is how the independent re-run succeeded here.
3. Return the 6-section package at **INT-1 v1.0.1**.

---

## 7. Related, not part of this order

- **M3 Progress Logger was never delivered.** INT-1 stubs it inline. The M3 work order (`M3_WORK_ORDER_v1.0.md`) is outstanding — M3 must be built and verified before the app is complete.
- **INT-2's APK was not built** — the Builder sandbox has no Android SDK/Java/Gradle, and the 2 GB RAM would likely not survive a Gradle build anyway. The widget sources are delivered and honest; the build needs an Android toolchain.
