# MODULE WORK ORDER — M2 Book Intake
**Order revision: v1.1**  ·  **Target module Version Stamp: v1.0**  ·  Date 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts.

This order is **fully self-contained** — it carries all nine mandatory items *and* the build prerequisites, so it does not depend on any separate preamble. The Stack Builder Agent sees only this document.

> Track note: M1 Library Store is **verified at v1.0.2** (Gate 5B Dual PASS, real `flutter test`, 5/5). M2 codes against M1's **frozen contract**, not its internals.

---

## 0. Before you start — build prerequisites (learned building M1)

| Thing | Value |
|---|---|
| Flutter | **3.47.7** (stable) |
| Dart | **3.13.5** (bundled) |
| Codegen before test | `dart run build_runner build` **must run before** `flutter test` |
| Project name | **`shelf_app`** — never `shelf` (it clashes with a published library `build_runner` needs) |
| Module folder | `src/modules/` |
| Test folder | `tests/` |

**`build.yaml` is mandatory.** Dart's build tooling scans only `lib/`, `test/`, `bin/`, `web/` by default. Because modules live in `src/`, drift's generator **silently writes ZERO outputs** unless this file is committed:

```yaml
targets:
  $default:
    sources:
      - "$package$"
      - "lib/**"
      - "src/**"
      - "tests/**"
      - "test/**"
      - "bin/**"
      - "web/**"
```

Symptom if missing: `build_runner` reports success, writes 0 outputs, and the module then fails to compile with `part '....g.dart' not found`.

**Three Dart correctness rules (these caused real compile failures on M1 — ADR-012):**
1. `part '....g.dart';` must come **after** all `import` directives. Above the imports is invalid Dart.
2. Narrow nullable fields to `String?` before use — an `Object?` cannot be used as `.isEmpty`; cast explicitly (e.g. `Value<String?>(fileUri)`).
3. Match the real drift return type — `customSelect(...).getSingle()` returns **`QueryRow`**, not `TypedResult`.

**Pin rule (ADR-010):** confirm every version exists as published for that exact package before writing it into `pubspec.yaml`. A package and its companion do not share a release line.

---

## 1. Module identity

| Field | Value |
|---|---|
| Module ID | M2 |
| Target module Version Stamp | v1.0 (first build of M2) |
| Target Module File Path | `src/modules/m2_book_intake.dart` |
| Target Test File Path | `tests/test_m2_book_intake.dart` |
| One-line purpose | Take a book — a device ebook (PDF/EPUB) or a manual/offline entry — validate it, import the file if present, and hand the clean result to M1. Never touches the database itself. |

---

## 2. Exact tech stack & pinned dependencies (never unpinned)

| Layer | Package | Pin |
|---|---|---|
| SDK | Flutter | 3.47.7 (stable) |
| Language | Dart | 3.13.5 (bundled with Flutter 3.47.7) |
| Storage (via M1) | drift | 2.35.2 |
| Storage codegen | drift_dev | **2.35.1** (2.35.2 is not published) |
| Native sqlite | sqlite3_flutter_libs | **0.5.42** (deliberate pin — `0.6.0+eol` is a retired no-op that bundles nothing) |
| Paths | path_provider | 2.1.6 |
| PDF parsing | pdfx | 2.11.0 |
| EPUB parsing | epubx | 4.0.0 |
| Codegen runner | build_runner | 2.16.2 |
| File picking | file_picker | **verify the exact published version, or record it from `pubspec.lock` — do NOT guess** |
| Test | flutter_test | from the Flutter SDK |

---

## 3. Verbatim Central Interface Registry row for M2 (from Table 2A)

| ID | Plain-English Job | Machine Input Contract | Machine Output Contract | Explicit Error Shapes | Forbidden Direct Couplings |
|---|---|---|---|---|---|
| M2 | Book Intake — add a device ebook or a manual/offline book | `{category_id, source:"device_file"\|"manual", file_uri?, title, total_pages?, cover_ref?}` | `{ok:true, book_id, category_id, total_pages, source}` | E1,E2,E3,E4,E6,E7,E8 | never writes DB directly — calls M1 |

---

## 4. Machine Input Socket Contract (exact)

```
{
  category_id: string (uuid, non-empty),
  source: "device_file" | "manual",
  file_uri: string | null,      // REQUIRED when source == "device_file"
  title: string,                // 1..200 chars
  total_pages: int | null,      // REQUIRED when source == "manual"; ignored for device_file
  cover_ref: string | null,
  idempotency_key: string       // REQUIRED (M2 is state-changing; passed straight to M1)
}
```

Boundary validation, in this order:

| Check | Failure |
|---|---|
| unknown/extra field, missing required field, wrong type | **E1** |
| `category_id` empty or not a string | **E1** |
| `title` length not in 1..200 | **E1** |
| `source` not in the enum | **E1** |
| `source == "manual"` and `total_pages` missing/not int | **E1** |
| `source == "manual"` and `total_pages` not in 1..20000 | **E2** |
| `source == "device_file"` and `file_uri` null/empty | **E1** |
| `idempotency_key` empty | **E1** |
| device file extension not in {`.pdf`, `.epub`} | **E6** |
| device file larger than `MAX_IMPORT_MB`, or unreadable/corrupt, or page count not extractable | **E6** |
| file access permission refused by the FileAccess port | **E8** |
| category does not exist (returned by M1) | **E4** |
| category already holds `MAX_BOOKS_PER_CATEGORY` books (returned by M1) | **E3** |

**Design requirement — inject a `FileAccess` port.** M2 must not call `file_picker`/`dart:io` directly. It takes an injected interface (e.g. `FileAccess.pickAndRead()` returning bytes + name, plus `FileAccess.copyToAppStorage()`), so E6/E7/E8 are testable with a fake and the platform dependency stays isolated at the edge.

---

## 5. Machine Output Socket Contract (exact)

Success: `{ ok: true, data: { book_id, category_id, total_pages, source }, schema_version: 1 }`
Failure: `{ ok: false, error: { code: "E*", message: string, field?: string } }`

`total_pages` is the value M1 stored: for `manual` it is the user-supplied number; for `device_file` it is the **extracted** count.

| Code | Name | Trigger |
|---|---|---|
| E1 | INVALID_INPUT | unknown/extra/missing field, wrong type, empty title, bad `source`, missing `total_pages` (manual), missing `file_uri` (device_file), empty key |
| E2 | OUT_OF_RANGE | `total_pages` not in 1..20000 (manual) |
| E3 | LIMIT_EXCEEDED | target category already holds 6 books — **passed through from M1 unchanged** |
| E4 | NOT_FOUND | `category_id` does not exist — **passed through from M1 unchanged** |
| E6 | UNSUPPORTED_FORMAT | extension not pdf/epub; file over `MAX_IMPORT_MB`; corrupt/unreadable; page count not extractable |
| E7 | STORAGE_ERROR | copy to app-private storage failed; DB write failed (from M1) |
| E8 | PERMISSION_DENIED | the FileAccess port refused file access |

---

## 6. Control switches & data pipes owned by M2

- **C3 (source branch)** — `manual` → require `total_pages`; `device_file` → require `file_uri`, validate format/size, copy, extract.
- **C2 (capacity, delegated)** — M2 does not decide the cap; M1 enforces it and M2 passes E3 back. Do not duplicate the cap here.
- **C7 (permission gate)** — if the FileAccess port refuses, return E8; do not crash.
- **D3 (ebook import pipe)** — validate → copy the file into app-private storage (via `path_provider`) → extract page count (pdfx/epubx) → call M1 `add_book` with `source:"device_file"` and the stored `file_path`.
- **D1 (catalog, delegated)** — the catalog write is M1's; M2 only calls it.

---

## 7. Failure & security guards

- **Import timeout + backoff (S3):** parsing bounded to 15 s; on failure retry at most twice with 1 s → 2 s backoff, then stop. On final failure return **E6** and leave the app usable — the caller may fall back to manual entry.
- **Size cap (S3):** reject any file over `MAX_IMPORT_MB` with E6 **before** reading it fully.
- **Storage check (S8):** before copying, confirm free space; if the copy fails, return E7 and leave no partial file behind.
- **Permission fallback (S7):** a refused pick returns E8; the caller may re-offer manual entry.
- **Idempotency (S1):** pass `idempotency_key` straight to M1. A repeated key must not create a second book.
- **Zero hardcoded secrets:** none exist; none may be introduced.
- **Config variable names (`.env` / build-time defines):** `MAX_IMPORT_MB`, `MAX_BOOKS_PER_CATEGORY`, `LOG_LEVEL`. `MAX_IMPORT_MB` must default to a safe value (e.g. 100).

**Design decision to confirm (flagged):** EPUB is reflowable and has no fixed pages. Default ruling: for EPUB, `total_pages` = the **spine item count**; for PDF, the real page count. If the product wants character-based pagination instead, that is an operator decision — state it before coding so the percentage maths stays consistent.

---

## 8. Mandatory 5-Part Verification & Definition of Done

Write `tests/test_m2_book_intake.dart` using `flutter_test`, a fresh in-memory M1, and a **fake `FileAccess`** (no real file picker). All five must pass.

- **Test 1 — Happy-Path Acceptance.** Add a manual book (valid) → success with the given `total_pages`. Add a small valid PDF via the fake port → success with the extracted page count. Assert both land in M1.
- **Test 2 — Boundary & Idempotency Breaker.** 7th book in a full category → E3. A file over `MAX_IMPORT_MB` → E6. A repeated `idempotency_key` → the book is added once, not twice.
- **Test 3 — Explicit Error-Shape Coverage.** One case each for E1, E2, E3, E4, E6, E7, E8 — each asserting the exact `error.code` (E8 driven by the fake port refusing).
- **Test 4 — Registry Seam Contract Test.** Assert the OUT `data` keys are exactly `{book_id, category_id, total_pages, source}` with the declared types, and `schema_version == 1`.
- **Test 5 — End-to-End Smoke & Health Probe.** M2 boots against a fresh M1, a probe returns healthy, and the M2→M1 seam works end to end.

**Definition of Done:** the module **compiles**; all 5 tests pass on Flutter 3.47.7; `pubspec.lock` committed with exact versions; no secret literals; M2 imports nothing from the UI or the database layer directly; the FileAccess port is the only platform touch-point.

**Return format (Gate 5B Return Package)** — exactly these six sections:
1. Module ID + Version Stamp
2. Target Module File Path + Target Test File Path
3. `.env.example` block
4. Pinned Dependency Manifest (exact versions + `pubspec.lock` hash)
5. Full contents of `src/modules/m2_book_intake.dart` and `tests/test_m2_book_intake.dart`
6. The 5-part Verification Execution Receipt — **real `flutter test` output**, one PASS/FAIL line per Test 1–5

A rules-only harness may corroborate but never satisfies this gate (ADR-012).

---

## 9. Required Zero-AI Module Passport header

```
# ============================================================
# MODULE PASSPORT — M2 Book Intake
# Version Stamp : v1.0
# Module File   : src/modules/m2_book_intake.dart
# Test File     : tests/test_m2_book_intake.dart
# Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.1 (Table 2A, row M2)
# ------------------------------------------------------------
# SAFE TO EDIT  : private helper functions, log messages, the
#                 MAX_IMPORT_MB default, retry count within limits
# DO NOT TOUCH  : the IN/OUT contract field names and types,
#                 the error codes E1..E9, the delegation to M1
#                 (M2 must never write to the DB itself)
# ============================================================
```
