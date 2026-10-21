# MODULE WORK ORDER — M4 Daily Engine
**Order revision: v1.0**  ·  **Target module Version Stamp: v1.0**  ·  Date 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts.

This order is **fully self-contained** — all nine mandatory items *and* the build prerequisites. The Stack Builder Agent sees only this document.

> Track note: M1 v1.0.2 and M2 v1.0 are VERIFIED (independently reproduced). M3 is issued and in build. M4 codes against M1's frozen contract. An M1 fix order targets v1.0.3 (finding F3); M4 does not depend on it.

---

## 0. Before you start — build prerequisites (learned building M1 and M2)

| Thing | Value |
|---|---|
| Flutter | **3.47.7** (stable) · Dart **3.13.5** |
| Codegen before test | `dart run build_runner build` **must run before** `flutter test` |
| Project name | **`shelf_app`** — never `shelf` |
| Folders | modules in `src/modules/` · tests in `tests/` · **`build.yaml` mandatory** (src/ is not scanned by default) |

**Dart correctness rules (ADR-012):** `part` after imports; narrow `Object?` to `String?` before `.isEmpty`; `customSelect(...).getSingle()` returns `QueryRow`, not `TypedResult`.
**Platform rule (ADR-015):** no `file_picker` / `dart:io` / `pdfx` / `epubx` imports — keep platform access behind injectable ports.
**Pin rule (ADR-010):** verify every version exists as published before pinning.

---

## 1. Module identity

| Field | Value |
|---|---|
| Module ID | M4 |
| Target module Version Stamp | v1.0 |
| Target Module File Path | `src/modules/m4_daily_engine.dart` |
| Target Test File Path | `tests/test_m4_daily_engine.dart` |
| One-line purpose | Compose the day view: given a date and timezone, return total pages read today and a per-book percentage, ready for the widget (M5) and the grid (M7). Owns the timezone-aware "today" and the clock-anomaly guard. |

**Honest scope note:** M1 already stores the per-day rows (`daily_summary`). M4 does **not** re-aggregate from the raw log — it reads M1's day rows and composes the caller-facing view. Its genuine responsibilities are (a) the timezone-aware local date, (b) the anomaly guard, and (c) shaping the payload M5/M7 consume. Keep it thin; do not duplicate M1's storage.

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

M4 needs **no** parser, file-picker or widget dependency. Do not add any.

---

## 3. Verbatim Central Interface Registry row for M4 (from Table 2A)

| ID | Plain-English Job | Machine Input Contract | Machine Output Contract | Explicit Error Shapes | Forbidden Direct Couplings |
|---|---|---|---|---|---|
| M4 | Daily Engine — pages-today, per-book %, midnight rollover | `{as_of_date, timezone_offset_min}` | `{ok,date,total_pages_today,per_book[]}` | E1,E2,E4 | no widget push (M5), no file reads |

---

## 4. Machine Input Socket Contract (exact)

```
{
  as_of_date: "YYYY-MM-DD",        // the day to report
  timezone_offset_min: int         // minutes offset from UTC, e.g. +330 for IST
}
```

Boundary validation, in this order:

| Check | Failure |
|---|---|
| unknown/extra field, missing required field, wrong type | **E1** |
| `as_of_date` not a valid `YYYY-MM-DD` date | **E1** |
| `timezone_offset_min` not an int | **E1** |
| `timezone_offset_min` not in `-720 .. 840` | **E2** |
| the date resolves to no books at all (nothing to report) | **E4** only if a required referenced entity is missing — an empty day is **not** an error (return zeros) |

**Design requirement — inject a `Clock` port.** M4 must not call `DateTime.now()` directly. It takes an injected `Clock` so "today" is deterministic in tests, and so the timezone offset is applied explicitly rather than implicitly.

**Anomaly guard (S5):** if the device clock has jumped backwards (a computed `pages_today` would be negative), clamp to `0` and log an anomaly line. Never return a negative count.

---

## 5. Machine Output Socket Contract (exact)

Success: `{ ok: true, data: { date, total_pages_today, per_book }, schema_version: 1 }`
Failure: `{ ok: false, error: { code: "E*", message: string, field?: string } }`

`data` shape:
```
{
  date: "YYYY-MM-DD",
  total_pages_today: int,                     // sum of per_book pages_today
  per_book: [ { book_id: string, pages_today: int, pct_today: float (0..100) } ]
}
```
`per_book` may be empty (an empty day) — that is a success with zeros, not an error.

| Code | Name | Trigger |
|---|---|---|
| E1 | INVALID_INPUT | unknown/extra/missing field, wrong type, invalid date |
| E2 | OUT_OF_RANGE | `timezone_offset_min` outside `-720..840` |
| E4 | NOT_FOUND | a referenced entity required to compose the view is missing |

---

## 6. Control switches & data pipes owned by M4

- **C5 (daily rollover)** — M4 owns the timezone-aware "today". It reads the day via M1 `read_daily(as_of_date)`; a new date simply yields a fresh (empty) day — there is no destructive reset.
- **D4 (daily aggregate, read side)** — M4 reads the day rows; the write side is M1's. Do **not** write `daily_summary` from M4.
- **Feeds M5/M7** — the composed view is what the widget and grid consume. M4 does **not** push to the widget; M5 does.

---

## 7. Failure & security guards

- **Anomaly guard (S5):** clamp any negative day count to 0 and log it; never surface a negative.
- **Empty day is success:** return zeros, not an error.
- **No widget push, no file reads:** if you reach for those, stop — they belong to M5.
- **Zero hardcoded secrets:** none exist; none may be introduced.
- **Config variable names (`.env` / build-time defines):** `DEFAULT_DAILY_GOAL_PAGES` (M4 may echo the goal for the widget payload), `LOG_LEVEL`.

---

## 8. Mandatory 5-Part Verification & Definition of Done

Write `tests/test_m4_daily_engine.dart` using `flutter_test`, a fresh in-memory M1, and an injected fake `Clock`. All five must pass.

- **Test 1 — Happy-Path Acceptance.** Log progress for a date via M1, then M4 → correct `total_pages_today` and per-book `pct_today`.
- **Test 2 — Boundary & Idempotency Breaker.** An empty day → zeros, success (not an error). A backwards clock jump → negatives clamped to 0.
- **Test 3 — Explicit Error-Shape Coverage.** One case each for E1, E2, E4 — exact `error.code`.
- **Test 4 — Registry Seam Contract Test.** OUT `data` keys exactly `{date, total_pages_today, per_book}`, each `per_book` entry exactly `{book_id, pages_today, pct_today}`, `schema_version == 1`.
- **Test 5 — End-to-End Smoke & Health Probe.** M4 boots against a fresh M1; the M4→M1 seam works end to end.

**Definition of Done:** compiles; all 5 tests pass on Flutter 3.47.7; no secret literals; no platform packages imported; M4 writes nothing to the database.

**Return format (Gate 5B Return Package)** — exactly six sections: (1) Module ID + Version Stamp; (2) both file paths; (3) `.env.example`; (4) pinned manifest + `pubspec.lock` hash; (5) full contents of both files; (6) the 5-part receipt with **real `flutter test` output**.

---

## 9. Required Zero-AI Module Passport header

```
# ============================================================
# MODULE PASSPORT — M4 Daily Engine
# Version Stamp : v1.0
# Module File   : src/modules/m4_daily_engine.dart
# Test File     : tests/test_m4_daily_engine.dart
# Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M4)
# ------------------------------------------------------------
# SAFE TO EDIT  : private helper functions, log messages, the
#                 DEFAULT_DAILY_GOAL_PAGES echo
# DO NOT TOUCH  : the IN/OUT contract field names and types,
#                 the error codes E1..E9, the rule that M4 writes
#                 nothing and does not push to the widget
# ============================================================
```
