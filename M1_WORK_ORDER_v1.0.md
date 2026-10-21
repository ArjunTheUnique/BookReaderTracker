# MODULE WORK ORDER — M1 Library Store
**Version Stamp: v1.0**  ·  Issued at Gate 5A  ·  Date 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts.
This order is fully self-contained. The Stack Builder Agent sees only this document and nothing else.

---

## 1. Module identity

| Field | Value |
|---|---|
| Module ID | M1 |
| Version Stamp | v1.0 |
| Target Module File Path | `src/modules/m1_library_store.dart` |
| Target Test File Path | `tests/test_m1_library_store.dart` |
| One-line purpose | The single source of truth: own the local SQLite database and be the only component that reads or writes categories, books, reading progress and daily summaries. |

Both file paths are taken verbatim from the Gate 4 Master Folder Tree. Do not rename, relocate or nest them.

---

## 2. Exact tech stack & pinned dependencies (never unpinned)

| Layer | Package | Pinned version |
|---|---|---|
| SDK | Flutter | 3.47.7 (stable), pinned via FVM (`.fvmrc`) |
| Language | Dart | bundled with Flutter 3.47.7 (≥3.10) |
| Database | drift | 2.35.2 |
| Database codegen | drift_dev | 2.35.2 (dev dependency; run via build_runner) |
| Database native lib | sqlite3_flutter_libs | record the exact version from `pubspec.lock` |
| Paths | path_provider | record the exact version from `pubspec.lock` |
| Test | flutter_test | from the Flutter SDK |
| Test DB | drift `NativeDatabase.memory()` | in-memory SQLite for tests |

Rules: pin every version exactly; commit `pubspec.lock`; add no dependency that is not listed here without a new work order.

---

## 3. Verbatim Central Interface Registry row for M1 (copied from Table 2A)

| ID | Plain-English Job | Machine Input Contract | Machine Output Contract | Explicit Error Shapes | Forbidden Direct Couplings |
|---|---|---|---|---|---|
| M1 | Library Store — single source of truth; owns the local DB | `{op, payload, idempotency_key, schema_version}` | `{ok:true, data:{…}, schema_version}` | E1,E2,E3,E4,E5,E7 | no UI / widget / file-picker imports |

---

## 4. Machine Input Socket Contract (exact)

The single entry point receives an **operation envelope**:

```
{
  op: "upsert_category" | "add_book" | "update_progress" | "read_catalog" | "read_daily" | "delete_book",
  payload: <object, shape per op below>,
  idempotency_key: <string|null>,   // REQUIRED (non-null) for add_book and update_progress
  schema_version: <int>             // MUST equal 1
}
```

**payload shapes and boundary validation rules:**

| op | payload fields (exact) | Validation (boundary rules) |
|---|---|---|
| `upsert_category` | `category_id:string(uuid)`, `name:string`, `position:int` | name length 1–40; position 0–5; creating a NEW category when 6 already exist → **E3** |
| `add_book` | `book_id:string(uuid)`, `category_id:string`, `title:string`, `total_pages:int`, `source:"device_file"\|"manual"`, `file_path:string\|null`, `cover_ref:string\|null` | category_id must exist → else **E4**; category must hold <6 books → else **E3**; title length 1–200 → else **E1**; total_pages 1–20000 → else **E2**; source must be in the enum → else **E1**; if source=="device_file" then file_path must be non-null → else **E1**; a book_id that already exists → **E5**; idempotency_key required |
| `update_progress` | `book_id:string`, `current_page:int`, `read_on:"YYYY-MM-DD"` | book_id must exist → else **E4**; 0 ≤ current_page ≤ total_pages → else **E2**; read_on must match `YYYY-MM-DD` → else **E1**; idempotency_key required |
| `read_catalog` | `{}` (empty) | none |
| `read_daily` | `as_of_date:"YYYY-MM-DD"` | valid date format → else **E1** |
| `delete_book` | `book_id:string` | book_id must exist → else **E4** |

Envelope-level rules: unknown `op` → **E1**; `schema_version` ≠ 1 → **E1**; a required field missing or of the wrong type → **E1**.

**Idempotency key requirement (state-changing ops):** every `add_book` and `update_progress` call MUST carry a non-null `idempotency_key`. A repeated key MUST NOT write a second time — the call returns success with `saved:false`. This is a silent no-op, **not** an error. (E5 DUPLICATE is reserved for inserting a `book_id` that already exists, which is a genuine conflict.)

---

## 5. Machine Output Socket Contract (exact)

Success:
```
{ ok: true, data: <object per op below>, schema_version: 1 }
```
Failure (single shared shape):
```
{ ok: false, error: { code: "E*", message: string, field?: string } }
```

**`data` shape per op:**

| op | data fields (exact types) |
|---|---|
| `upsert_category` | `{ category_id:string }` |
| `add_book` | `{ book_id:string, category_id:string, book_count:int (0–6) }` |
| `update_progress` | `{ book_id:string, current_page:int, pct_read:float (0–100), saved:bool }` |
| `read_catalog` | `{ categories:[ { category_id:string, name:string, position:int, books:[ { book_id:string, title:string, total_pages:int, source:string, cover_ref:string\|null } ] } ] }` — exactly 6 categories, each with ≤6 books |
| `read_daily` | `{ date:"YYYY-MM-DD", total_pages_today:int, per_book:[ { book_id:string, pages_today:int, pct_today:float (0–100) } ] }` |
| `delete_book` | `{ book_id:string, deleted:true }` |

**Explicit error shapes and their exact trigger conditions:**

| Code | Name | Trigger (exact) |
|---|---|---|
| E1 | INVALID_INPUT | unknown op; schema_version ≠ 1; missing/extra field; wrong type; empty or over-long title; invalid `read_on`/`as_of_date` format; `source` not in enum; `file_path` null when source=="device_file" |
| E2 | OUT_OF_RANGE | `total_pages` not in 1–20000; `current_page` not in 0–total_pages; `position` not in 0–5 |
| E3 | LIMIT_EXCEEDED | creating a 7th category; adding a 7th book to a category |
| E4 | NOT_FOUND | `category_id` or `book_id` does not exist |
| E5 | DUPLICATE | `add_book` with a `book_id` that already exists |
| E7 | STORAGE_ERROR | the database write/read failed (disk full, IO error) |

Note: a repeated `idempotency_key` is **not** an error (see §4) — it returns `{ ok:true, saved:false }`.

---

## 6. Control switches & data pipes owned by M1

**Control switches (decisions):**
- **C1 (launch)** — on first launch, if no categories exist, seed exactly 6 empty categories named "Category 1"…"Category 6" with 0 books, so the home grid always renders 6 tiles.
- **C2 (add book)** — reject the add when the target category already holds 6 books.
- **C5 (rollover support)** — expose `read_daily(as_of_date)` so M4 can compute "today" from the device-local date.

**Data pipes (transport + storage):**
- **D1 Catalog** → SQLite table `books` (categories + books).
- **D2 Progress event** → SQLite table `progress_log` (book_id, current_page, read_on, idempotency_key, created_at).
- **D4 Daily aggregate** → SQLite table `daily_summary` (book_id, date, pages_today, pct_today).

Storage location: an app-private directory obtained via `path_provider` (never a world-readable path). DB file name from config (`DB_FILE_NAME`).

---

## 7. Failure & security guards

- **Atomic writes:** every state-changing op runs inside a single Drift transaction. Enable WAL: `PRAGMA journal_mode=WAL`. A crash mid-write must leave the DB unchanged.
- **Idempotency:** the `progress_log` table has a `UNIQUE(idempotency_key)` constraint; a repeated key is caught here and turned into `saved:false`.
- **Integrity probe:** expose a health method that runs `PRAGMA integrity_check`; return `"ok"` on success so the caller (M6) can trigger a restore when it is not `"ok"`.
- **Timeouts/retries:** local-only, so no network retry is needed; set SQLite `busy_timeout = 5000 ms` so concurrent widget reads do not fail.
- **Zero hardcoded secrets:** no credentials exist and none may be introduced. All tunables come from config.
- **Config variable names (`.env` / build-time defines):** `DB_FILE_NAME`, `MAX_CATEGORIES` (=6), `MAX_BOOKS_PER_CATEGORY` (=6), `LOG_LEVEL`. The 6/6 caps are read from config but MUST default to 6 and MUST be enforced here, not only in the UI.

---

## 8. Mandatory 5-Part Verification & Definition of Done

Write `tests/test_m1_library_store.dart` using `flutter_test` and an in-memory Drift database. All five must pass.

- **Test 1 — Happy-Path Acceptance.** Seed 6 categories; add 6 books to category 1; call `update_progress`; then `read_catalog` and assert the exact returned structure and values (6 categories, category 1 has 6 books, `pct_read` computed correctly).
- **Test 2 — Boundary & Idempotency Breaker.** Adding a 7th category → E3. Adding a 7th book to a full category → E3. Calling `update_progress` twice with the same `idempotency_key` → first `saved:true`, second `saved:false`, and the progress row count is unchanged.
- **Test 3 — Explicit Error-Shape Coverage.** One test per declared shape: E1, E2, E3, E4, E5, E7 — each asserting the exact `error.code`.
- **Test 4 — Registry Seam Contract Test.** Assert that the OUT object for each op contains exactly the field names from §5, with the declared types (string/int/float/bool), and that `schema_version == 1`.
- **Test 5 — End-to-End Smoke & Health-Check Probe.** On a fresh in-memory DB: boot, `PRAGMA integrity_check` returns `"ok"`, and `read_catalog` returns exactly 6 empty categories with 0 books.

**Definition of Done:** all 5 tests pass; `pubspec.lock` committed with exact versions; no secret literals; the module imports nothing from the UI, widget, or file-picker layers.

**Return format (Gate 5B Return Package)** — paste back exactly these six sections:
1. Module ID + Version Stamp
2. Target Module File Path + Target Test File Path (as written)
3. `.env.example` block
4. Pinned Dependency Manifest (`pubspec.yaml` deps with exact versions + `pubspec.lock` hash)
5. The full contents of `src/modules/m1_library_store.dart` and `tests/test_m1_library_store.dart`
6. The 5-part Verification Execution Receipt (one PASS/FAIL line per Test 1–5 with the command run and its output)

---

## 9. Required Zero-AI Module Passport header

Both files MUST begin with this header, filled in:

```
# ============================================================
# MODULE PASSPORT — M1 Library Store
# Version Stamp : v1.0
# Module File   : src/modules/m1_library_store.dart
# Test File     : tests/test_m1_library_store.dart
# Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.0 (Table 2A, row M1)
# ------------------------------------------------------------
# SAFE TO EDIT  : private helper functions, internal query text,
#                 local variable names, log messages
# DO NOT TOUCH  : the IN/OUT contract field names and types,
#                 the error codes E1..E9, the idempotency rule,
#                 the 6-category / 6-book caps, schema_version
# ============================================================
```
