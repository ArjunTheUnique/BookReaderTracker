# MODULE WORK ORDER — M7 Grid Presenter
**Order revision: v1.0**  ·  **Target module Version Stamp: v1.0**  ·  Date 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts.

This order is **fully self-contained**. The Stack Builder Agent sees only this document.

> Track note: M1 v1.0.2 and M2 v1.0 VERIFIED; M3–M6 issued. M7 is the **last module** before integration (app shell + native widget shells + packaging). It is **read-only**.

---

## 0. Before you start — build prerequisites

| Thing | Value |
|---|---|
| Flutter | **3.47.7** (stable) · Dart **3.13.5** |
| Codegen before test | `dart run build_runner build` before `flutter test` |
| Project name | **`shelf_app`** — never `shelf` |
| Folders | modules in `src/modules/` · tests in `tests/` · **`build.yaml` mandatory** |

**Dart rules (ADR-012):** `part` after imports; narrow `Object?` to `String?` before `.isEmpty`; `customSelect(...).getSingle()` → `QueryRow`.
**Platform rule (ADR-015):** M7 must not import any platform package; it reads only through M1/M4 ports.
**Pin rule (ADR-010):** verify every version exists as published before pinning.

---

## 1. Module identity

| Field | Value |
|---|---|
| Module ID | M7 |
| Target module Version Stamp | v1.0 |
| Target Module File Path | `src/modules/m7_grid_presenter.dart` |
| Target Test File Path | `tests/test_m7_grid_presenter.dart` |
| One-line purpose | Build the exact view-models the home grid and book tiles render, enforcing the 6-category × 6-book no-scroll shape. Reads the catalog from M1 and today's percentages from M4. Never writes. |

---

## 2. Exact tech stack & pinned dependencies

| Layer | Package | Pin |
|---|---|---|
| SDK | Flutter | 3.47.7 (stable) |
| Language | Dart | 3.13.5 |
| Storage (via M1) | drift | 2.35.2 |
| Storage codegen | drift_dev | 2.35.1 |
| Native sqlite | sqlite3_flutter_libs | 0.5.42 |
| Paths | path_provider | 2.1.6 |
| Codegen runner | build_runner | 2.16.2 |
| Test | flutter_test | from the Flutter SDK |

M7 needs **no** parser, file-picker or widget dependency. Do not add any.

---

## 3. Verbatim Central Interface Registry row for M7 (from Table 2A)

| ID | Plain-English Job | Machine Input Contract | Machine Output Contract | Explicit Error Shapes | Forbidden Direct Couplings |
|---|---|---|---|---|---|
| M7 | Grid Presenter — build 6×6 grid view-models, enforce no-scroll | `{view:"home"\|"category"\|"book", category_id?, book_id?}` | `{ok,categories[] (len 6)}` | E1,E4 | read-only via M1/M4 — never writes |

---

## 4. Machine Input Socket Contract (exact)

```
{
  view: "home" | "category" | "book",
  category_id: string | null,   // REQUIRED when view == "category"
  book_id: string | null        // REQUIRED when view == "book"
}
```

Boundary validation:

| Check | Failure |
|---|---|
| unknown/extra field, missing required field, wrong type | **E1** |
| `view` not in the enum | **E1** |
| `view == "category"` and `category_id` missing/empty | **E1** |
| `view == "book"` and `book_id` missing/empty | **E1** |
| `category_id` / `book_id` does not exist | **E4** |

---

## 5. Machine Output Socket Contract (exact)

Success: `{ ok: true, data: <per view>, schema_version: 1 }`
Failure: `{ ok: false, error: { code: "E*", message: string, field?: string } }`

**home:**
```
{ categories: [
    { category_id:string, name:string, book_count:int (0..6),
      books: [ { book_id:string, title:string, cover_ref:string|null, pct_today:float (0..100) } ] } ] }   // exactly 6 categories
```
**category:** `{ category_id, name, book_count, books:[…] }` for the one category.
**book:** `{ book_id, title, cover_ref, pct_today }` for the one book.

`pct_today` comes from **M4**; `title`/`cover_ref` come from **M1**. M7 composes, it does not compute.

| Code | Name | Trigger |
|---|---|---|
| E1 | INVALID_INPUT | unknown/extra/missing field, wrong type, bad `view`, missing id for the view |
| E4 | NOT_FOUND | the referenced category or book does not exist |

---

## 6. Control switches & data pipes owned by M7

- **C1 (launch)** — on the home view, return the 6 seeded categories (M1 seeds them; M7 reflects them).
- **D7 (tile view-model pipe)** — compose each tile: id, title, cover_ref, pct_today.
- M7 is **read-only**: it calls M1 `read_catalog` and M4 for percentages; it never writes and never enforces the cap itself (M1 does).

---

## 7. Failure & security guards

- **Empty catalog is success:** a fresh library returns 6 empty tiles, not an error.
- **No writes, no maths:** M7 must never write to the database and must never compute a percentage itself.
- **Zero hardcoded secrets:** none exist; none may be introduced.
- **Config variable names:** `LOG_LEVEL` only.

---

## 8. Mandatory 5-Part Verification & Definition of Done

Write `tests/test_m7_grid_presenter.dart` using `flutter_test` and a fresh in-memory M1. All five must pass.

- **Test 1 — Happy-Path Acceptance.** A seeded library → the home view returns exactly 6 categories with correct `book_count` and `pct_today`.
- **Test 2 — Boundary & Idempotency Breaker.** Empty catalog → 6 empty tiles (success, not error); a full category shows exactly 6 books.
- **Test 3 — Explicit Error-Shape Coverage.** One case each for E1 (bad view / missing id) and E4 (unknown id) — exact `error.code`.
- **Test 4 — Registry Seam Contract Test.** OUT `data` keys exactly `{categories}`; each category key set `{category_id, name, book_count, books}`; each book key set `{book_id, title, cover_ref, pct_today}`; `schema_version == 1`.
- **Test 5 — End-to-End Smoke & Health Probe.** Boots against a fresh M1; all three views render end to end.

**Definition of Done:** compiles; all 5 pass on Flutter 3.47.7; no secret literals; M7 writes nothing and imports no platform package.

**Return format (Gate 5B Return Package)** — six sections: (1) ID + Version Stamp; (2) both paths; (3) `.env.example`; (4) pinned manifest + lockfile hash; (5) full contents of both files; (6) the 5-part receipt with **real `flutter test` output**.

---

## 9. Required Zero-AI Module Passport header

```
# ============================================================
# MODULE PASSPORT — M7 Grid Presenter
# Version Stamp : v1.0
# Module File   : src/modules/m7_grid_presenter.dart
# Test File     : tests/test_m7_grid_presenter.dart
# Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M7)
# ------------------------------------------------------------
# SAFE TO EDIT  : private helpers, log messages, tile field order
# DO NOT TOUCH  : the IN/OUT contract field names and types,
#                 the error codes, the rule that M7 never writes
#                 and never computes a percentage itself
# ============================================================
```
