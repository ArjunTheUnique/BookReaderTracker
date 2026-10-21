# MODULE WORK ORDER — M3 Progress Logger
**Order revision: v1.0**  ·  **Target module Version Stamp: v1.0**  ·  Date 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts.

This order is **fully self-contained** — it carries all nine mandatory items *and* the build prerequisites. The Stack Builder Agent sees only this document.

> Track note: M1 Library Store **v1.0.2** and M2 Book Intake **v1.0** are both VERIFIED (Gate 5B Dual PASS, independently reproduced). M3 codes against M1's **frozen contract**. Note: an open fix order targets M1 **v1.0.3** for the replay defect (finding F3) — M3 does not depend on that fix, but be aware M1's version may move.

---

## 0. Before you start — build prerequisites (learned building M1 and M2)

| Thing | Value |
|---|---|
| Flutter | **3.47.7** (stable) |
| Dart | **3.13.5** (bundled) |
| Codegen before test | `dart run build_runner build` **must run before** `flutter test` |
| Project name | **`shelf_app`** — never `shelf` |
| Module folder | `src/modules/` · Test folder `tests/` |
| `build.yaml` | **mandatory** — modules live in `src/`, which Dart's build tooling does not scan by default (see the committed file) |

**Dart correctness rules (caused real compile failures on M1 — ADR-012):**
1. `part '....g.dart';` must come **after** all `import` directives.
2. Narrow nullable fields to `String?` before use — an `Object?` cannot be used as `.isEmpty`.
3. `customSelect(...).getSingle()` returns **`QueryRow`**, not `TypedResult`.

**Platform rule (ADR-015):** M3 must **not** import `file_picker`, `dart:io`, `pdfx` or `epubx`. Keep platform access behind injectable ports.

**Pin rule (ADR-010):** confirm every version exists as published for that exact package before writing it into `pubspec.yaml`.

---

## 1. Module identity

| Field | Value |
|---|---|
| Module ID | M3 |
| Target module Version Stamp | v1.0 (first build of M3) |
| Target Module File Path | `src/modules/m3_progress_logger.dart` |
| Target Test File Path | `tests/test_m3_progress_logger.dart` |
| One-line purpose | Record how far a user has read, safely against double-taps: derive a stable idempotency key, validate, and forward to M1. Never touches the database or computes daily totals. |

---

## 2. Exact tech stack & pinned dependencies (never unpinned)

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

M3 needs **no** parser or file-picker dependency. Do not add any.

---

## 3. Verbatim Central Interface Registry row for M3 (from Table 2A)

| ID | Plain-English Job | Machine Input Contract | Machine Output Contract | Explicit Error Shapes | Forbidden Direct Couplings |
|---|---|---|---|---|---|
| M3 | Progress Logger — record how far read, safely vs double-taps | `{book_id, current_page, read_on, idempotency_key}` | `{ok, book_id, current_page, pct_read, saved}` | E1,E2,E4,E5 | no daily math (M4), no UI |

---

## 4. Machine Input Socket Contract (exact)

```
{
  book_id: string (uuid, non-empty),
  current_page: int,               // 0 .. the book's total_pages
  read_on: "YYYY-MM-DD",           // device-local date
  idempotency_key: string          // REQUIRED (M3 is state-changing)
}
```

Boundary validation, in this order:

| Check | Failure |
|---|---|
| unknown/extra field, missing required field, wrong type | **E1** |
| `book_id` empty or not a string | **E1** |
| `read_on` not a valid `YYYY-MM-DD` date | **E1** |
| `idempotency_key` empty | **E1** |
| `current_page` not an int | **E1** |
| `current_page` not in `0 .. total_pages` | **E2** |
| `book_id` does not exist (returned by M1) | **E4** |
| a genuine duplicate insert (returned by M1) | **E5** |

**Design requirement — inject a `Clock` port.** M3 must not call `DateTime.now()` directly for "today"; take an injected `Clock` (or a `today()` function) so tests are deterministic. This mirrors M2's port discipline (ADR-015).

**Idempotency key rule (M3's core responsibility):** derive a **stable** key from the logical save, e.g. `hash(book_id + read_on + current_page)`. Two identical saves produce the same key, so M1's ledger makes the second a silent no-op. The caller may also pass its own key; if it does, pass it through unchanged. Document the rule in the Module Passport.

---

## 5. Machine Output Socket Contract (exact)

Success: `{ ok: true, data: { book_id, current_page, pct_read, saved }, schema_version: 1 }`
Failure: `{ ok: false, error: { code: "E*", message: string, field?: string } }`

`pct_read` is a float in `0..100` (M1 returns it; M3 passes it through). `saved` is `true` on a real write and `false` on a replayed (ignored) write.

| Code | Name | Trigger |
|---|---|---|
| E1 | INVALID_INPUT | unknown/extra/missing field, wrong type, empty book_id, invalid date, empty key, non-int page |
| E2 | OUT_OF_RANGE | `current_page` outside `0..total_pages` |
| E4 | NOT_FOUND | `book_id` does not exist — **passed through from M1 unchanged** |
| E5 | DUPLICATE | a genuine duplicate — **passed through from M1 unchanged** |

Note: a repeated idempotency key is **not** an error — it returns `{ ok:true, saved:false }`.

---

## 6. Control switches & data pipes owned by M3

- **C4 (save progress)** — validate page range and date; derive the idempotency key; forward to M1. A repeated key returns `saved:false` without error.
- **D2 (progress pipe)** — the write is M1's `update_progress`; M3 only calls it. Do **not** touch `daily_summary` — that is M4's D4.
- M3 does **not** implement the "backward progress → confirm" prompt (S4); it only rejects out-of-range values with E2. Any confirmation UX belongs to the app shell.

---

## 7. Failure & security guards

- **Idempotency (S1):** the derived stable key is the whole guard — a double-tap must produce one row, not two.
- **No daily maths:** M3 must never aggregate or roll up. If you find yourself computing "pages today", stop — that is M4.
- **Zero hardcoded secrets:** none exist; none may be introduced.
- **Config variable names (`.env` / build-time defines):** `LOG_LEVEL` only. (No caps or sizes belong to M3.)
- **Graceful passthrough:** M1's E4/E5 are returned to the caller unchanged, never re-shaped.

---

## 8. Mandatory 5-Part Verification & Definition of Done

Write `tests/test_m3_progress_logger.dart` using `flutter_test`, a fresh in-memory M1, and an injected fake `Clock`. All five must pass.

- **Test 1 — Happy-Path Acceptance.** Valid progress on an existing book → success, correct `pct_read`, `saved:true`, and the row is present in M1.
- **Test 2 — Boundary & Idempotency Breaker.** `current_page` out of range → E2. The same logical save twice (same derived key) → exactly one row and the second returns `saved:false`.
- **Test 3 — Explicit Error-Shape Coverage.** One case each for E1, E2, E4, E5 — each asserting the exact `error.code`.
- **Test 4 — Registry Seam Contract Test.** Assert the OUT `data` keys are exactly `{book_id, current_page, pct_read, saved}` with the declared types, and `schema_version == 1`.
- **Test 5 — End-to-End Smoke & Health Probe.** M3 boots against a fresh M1, a probe returns healthy, and the M3→M1 seam works end to end.

**Definition of Done:** the module **compiles**; all 5 tests pass on Flutter 3.47.7; no secret literals; M3 imports nothing from the UI or the database layer directly; no platform packages imported (ADR-015).

**Return format (Gate 5B Return Package)** — exactly these six sections:
1. Module ID + Version Stamp
2. Target Module File Path + Target Test File Path
3. `.env.example` block
4. Pinned Dependency Manifest (exact versions + `pubspec.lock` hash)
5. Full contents of `src/modules/m3_progress_logger.dart` and `tests/test_m3_progress_logger.dart`
6. The 5-part Verification Execution Receipt — **real `flutter test` output**, one PASS/FAIL line per Test 1–5

A rules-only harness may corroborate but never satisfies this gate (ADR-012).

---

## 9. Required Zero-AI Module Passport header

```
# ============================================================
# MODULE PASSPORT — M3 Progress Logger
# Version Stamp : v1.0
# Module File   : src/modules/m3_progress_logger.dart
# Test File     : tests/test_m3_progress_logger.dart
# Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M3)
# ------------------------------------------------------------
# SAFE TO EDIT  : private helper functions, log messages, the
#                 idempotency-key derivation detail
# DO NOT TOUCH  : the IN/OUT contract field names and types,
#                 the error codes E1..E9, the delegation to M1,
#                 and the rule that M3 does NO daily maths
# ============================================================
```
