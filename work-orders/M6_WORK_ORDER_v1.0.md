# MODULE WORK ORDER — M6 Backup Vault
**Order revision: v1.0**  ·  **Target module Version Stamp: v1.0**  ·  Date 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts.

This order is **fully self-contained**. The Stack Builder Agent sees only this document.

> Track note: M1 v1.0.2 and M2 v1.0 VERIFIED; M3, M4, M5 issued. M6 restores only through **M1's atomic replace**.

---

## 0. Before you start — build prerequisites

| Thing | Value |
|---|---|
| Flutter | **3.47.7** (stable) · Dart **3.13.5** |
| Codegen before test | `dart run build_runner build` before `flutter test` |
| Project name | **`shelf_app`** — never `shelf` |
| Folders | modules in `src/modules/` · tests in `tests/` · **`build.yaml` mandatory** |

**Dart rules (ADR-012):** `part` after imports; narrow `Object?` to `String?` before `.isEmpty`; `customSelect(...).getSingle()` → `QueryRow`.
**Platform rule (ADR-015):** M6 must **not** import `dart:io` or the crypto package directly. Declare two ports — **`FileVault`** (read/write the `.rtbk` file) and **`Cipher`** (AES-256-GCM) — and put the real implementations in an adapter file the tests never import.
**Pin rule (ADR-010):** verify every version exists as published before pinning.

---

## 1. Module identity

| Field | Value |
|---|---|
| Module ID | M6 |
| Target module Version Stamp | v1.0 |
| Target Module File Path | `src/modules/m6_backup_vault.dart` |
| Target Test File Path | `tests/test_m6_backup_vault.dart` |
| One-line purpose | Export the whole library as one encrypted `.rtbk` file and restore it — validating schema version and checksum **before** any current data is replaced. |

---

## 2. Exact tech stack & pinned dependencies

| Layer | Package | Pin |
|---|---|---|
| SDK | Flutter | 3.47.7 (stable) |
| Language | Dart | 3.13.5 |
| Crypto (edge only) | cryptography | 2.9.0 |
| Crypto native accel (edge only) | cryptography_flutter | 2.3.4 |
| Storage (via M1) | drift | 2.35.2 |
| Storage codegen | drift_dev | 2.35.1 |
| Native sqlite | sqlite3_flutter_libs | 0.5.42 |
| Paths | path_provider | 2.1.6 |
| Codegen runner | build_runner | 2.16.2 |
| Test | flutter_test | from the Flutter SDK |

The crypto packages appear **only** in the adapter/edge file.

---

## 3. Verbatim Central Interface Registry row for M6 (from Table 2A)

| ID | Plain-English Job | Machine Input Contract | Machine Output Contract | Explicit Error Shapes | Forbidden Direct Couplings |
|---|---|---|---|---|---|
| M6 | Backup Vault — encrypted export / validating restore | export `{destination_uri, passphrase}` / restore `{source_uri, passphrase}` | `{ok,bytes,schema_version,checksum}` | E1,E7,E9 | restore only via M1 atomic replace |

---

## 4. Machine Input Socket Contract (exact)

**export:**
```
{ destination_uri:string (non-empty), passphrase:string (min length enforced) }
```
**restore:**
```
{ source_uri:string (non-empty), passphrase:string (min length enforced) }
```

Boundary validation:

| Check | Failure |
|---|---|
| unknown/extra field, missing required field, wrong type | **E1** |
| `destination_uri` / `source_uri` empty | **E1** |
| `passphrase` empty or shorter than the minimum (e.g. 8 chars) | **E1** |
| the file cannot be written or read (IO fault) | **E7** |
| the file's schema version is unknown, or the checksum fails, or the passphrase is wrong | **E9** |

The passphrase is **never stored** anywhere.

---

## 5. Machine Output Socket Contract (exact)

Success: `{ ok: true, data: { bytes:int, schema_version:int, checksum:string }, schema_version: 1 }`
Failure: `{ ok: false, error: { code: "E*", message: string, field?: string } }`

`checksum` is a hex string over the plaintext (or ciphertext — state which, and keep it consistent) so a restore can detect tampering.

| Code | Name | Trigger |
|---|---|---|
| E1 | INVALID_INPUT | unknown/extra/missing field, wrong type, empty uri, weak/empty passphrase |
| E7 | STORAGE_ERROR | the `.rtbk` file could not be written or read |
| E9 | BACKUP_INVALID | unknown schema version, checksum mismatch, or wrong passphrase |

---

## 6. Control switches & data pipes owned by M6

- **export (D6)** — snapshot the library → serialise → encrypt (AES-256-GCM) → write the `.rtbk` through the FileVault port.
- **restore (D6)** — read the file → decrypt → **validate schema version + checksum first** → hand the validated payload to **M1's atomic replace**. Never write partial state.
- **Health link** — M6 may call M1's `PRAGMA integrity_check` probe to decide whether a restore is needed.

---

## 7. Failure & security guards

- **Validate before overwrite (S8):** a bad file must be refused with E9 and the current data left **untouched**. This is the single most important rule in M6.
- **Atomic restore:** the swap is all-or-nothing; a failure mid-restore must leave the prior state intact.
- **Passphrase:** user-entered, never stored, never logged.
- **Zero hardcoded secrets:** none exist; none may be introduced.
- **Config variable names:** `BACKUP_CIPHER`, `LOG_LEVEL`.

---

## 8. Mandatory 5-Part Verification & Definition of Done

Write `tests/test_m6_backup_vault.dart` using `flutter_test`, a fresh in-memory M1, and **fake `FileVault` + `Cipher`** ports. All five must pass.

- **Test 1 — Happy-Path Acceptance.** Export a seeded library → a file is written; restore it → the data matches and the checksum verifies.
- **Test 2 — Boundary & Idempotency Breaker.** Wrong passphrase → E9; a corrupted file → E9; **assert the live data is unchanged** after both failures.
- **Test 3 — Explicit Error-Shape Coverage.** One case each for E1, E7, E9 — exact `error.code`.
- **Test 4 — Registry Seam Contract Test.** OUT keys exactly `{bytes, schema_version, checksum}`; `bytes` int, `schema_version` int, `checksum` string; `schema_version == 1`.
- **Test 5 — End-to-End Smoke & Health Probe.** Boots; a full export→restore round-trip works end to end against M1.

**Definition of Done:** compiles; all 5 pass on Flutter 3.47.7; no secret literals; no direct `dart:io`/crypto import in the module (ports only); a failed restore provably leaves data intact.

**Return format (Gate 5B Return Package)** — six sections: (1) ID + Version Stamp; (2) both paths; (3) `.env.example`; (4) pinned manifest + lockfile hash; (5) full contents of both files; (6) the 5-part receipt with **real `flutter test` output**.

---

## 9. Required Zero-AI Module Passport header

```
# ============================================================
# MODULE PASSPORT — M6 Backup Vault
# Version Stamp : v1.0
# Module File   : src/modules/m6_backup_vault.dart
# Test File     : tests/test_m6_backup_vault.dart
# Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M6)
# ------------------------------------------------------------
# SAFE TO EDIT  : private helpers, log messages, the checksum
#                 algorithm choice (keep it consistent)
# DO NOT TOUCH  : the IN/OUT contract field names and types,
#                 the error codes, the rule that a restore is
#                 validated BEFORE any overwrite, and that the
#                 passphrase is never stored
# ============================================================
```
