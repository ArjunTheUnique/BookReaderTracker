# MODULE WORK ORDER — M5 Widget Bridge
**Order revision: v1.0**  ·  **Target module Version Stamp: v1.0**  ·  Date 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts.

This order is **fully self-contained**. The Stack Builder Agent sees only this document.

> Track note: M1 v1.0.2 and M2 v1.0 VERIFIED; M3, M4 issued. M5 codes against frozen contracts and gets its payload from **M4**, never the database.

---

## 0. Before you start — build prerequisites

| Thing | Value |
|---|---|
| Flutter | **3.47.7** (stable) · Dart **3.13.5** |
| Codegen before test | `dart run build_runner build` before `flutter test` |
| Project name | **`shelf_app`** — never `shelf` |
| Folders | modules in `src/modules/` · tests in `tests/` · **`build.yaml` mandatory** |

**Dart rules (ADR-012):** `part` after imports; narrow `Object?` to `String?` before `.isEmpty`; `customSelect(...).getSingle()` → `QueryRow`.
**Platform rule (ADR-015):** M5 must **not** import the widget plugin directly — the native bridge goes behind an injectable **`WidgetHost`** port. (Note: `home_widget` and the native AppWidget/WidgetKit shells are Flutter/platform code and cannot run inside `flutter test`; the port is what makes the module testable.)
**Pin rule (ADR-010):** verify every version exists as published before pinning.

---

## 1. Module identity

| Field | Value |
|---|---|
| Module ID | M5 |
| Target module Version Stamp | v1.0 |
| Target Module File Path | `src/modules/m5_widget_bridge.dart` |
| Target Test File Path | `tests/test_m5_widget_bridge.dart` |
| One-line purpose | Build the widget payload from M4's day view, push it to the home-screen widget through the WidgetHost port, and turn a widget tap into a deep-link route back into the app. |

---

## 2. Exact tech stack & pinned dependencies

| Layer | Package | Pin |
|---|---|---|
| SDK | Flutter | 3.47.7 (stable) |
| Language | Dart | 3.13.5 |
| Widget plugin (edge only) | home_widget | 0.10.0 |
| Storage (via M4/M1) | drift | 2.35.2 |
| Storage codegen | drift_dev | 2.35.1 |
| Native sqlite | sqlite3_flutter_libs | 0.5.42 |
| Paths | path_provider | 2.1.6 |
| Codegen runner | build_runner | 2.16.2 |
| Test | flutter_test | from the Flutter SDK |

`home_widget` appears **only** in the adapter/edge file, never in the module or its test.

---

## 3. Verbatim Central Interface Registry row for M5 (from Table 2A)

| ID | Plain-English Job | Machine Input Contract | Machine Output Contract | Explicit Error Shapes | Forbidden Direct Couplings |
|---|---|---|---|---|---|
| M5 | Widget Bridge — build payload, push to widget, route taps | push `{goal_pages, total_pages_today, per_book_pct[]}` / tap `{target_type, target_id}` | `{ok,pushed_at}` / `{ok,route}` | E1,E7,E8 | gets payload from M4 — never queries DB |

---

## 4. Machine Input Socket Contract (exact)

Two request shapes:

**push** (refresh the widget):
```
{ goal_pages:int (>=0), total_pages_today:int (>=0), per_book_pct:[ { book_id:string, pct:float (0..100) } ] }
```
**tap** (a widget was tapped):
```
{ target_type:"book"|"category", target_id:string (non-empty) }
```

Boundary validation:

| Check | Failure |
|---|---|
| unknown/extra field, missing required field, wrong type | **E1** |
| `goal_pages` negative or not int | **E1** |
| `total_pages_today` negative or not int | **E1** |
| a `pct` outside `0..100` | **E1** |
| `target_type` not in the enum | **E1** |
| `target_id` empty | **E1** |
| the WidgetHost port fails to write the shared store | **E7** |
| the OS refuses the widget/notification permission | **E8** |

---

## 5. Machine Output Socket Contract (exact)

**push success:** `{ ok: true, data: { pushed_at: ISO8601 string }, schema_version: 1 }`
**tap success:** `{ ok: true, data: { route: string }, schema_version: 1 }`
Failure: `{ ok: false, error: { code: "E*", message: string, field?: string } }`

`route` is a non-empty deep-link string the app shell/M7 will open (e.g. `shelf://book/<id>`).

| Code | Name | Trigger |
|---|---|---|
| E1 | INVALID_INPUT | unknown/extra/missing field, wrong type, bad enum, empty id, out-of-range pct |
| E7 | STORAGE_ERROR | the WidgetHost port could not write the shared store |
| E8 | PERMISSION_DENIED | widget/notification permission refused |

---

## 6. Control switches & data pipes owned by M5

- **C6 (widget tap)** — map a tap to a deep-link route; hand it to the app shell.
- **D5 (widget payload pipe)** — format the payload and push it through the WidgetHost port to the shared app-group store; the OS widget reads that store on its own schedule.
- M5 receives the day view from **M4**; it does not read the database and does not compute the day itself.

---

## 7. Failure & security guards

- **Staleness (S6):** if the payload is empty or the store was not refreshed, the widget must show "—" + a last-updated stamp — never wrong numbers.
- **Permission fallback (S7):** a refused permission returns E8; the app keeps working without the widget.
- **Privacy (T7):** by default the widget shows **numbers only**; book titles are off unless `WIDGET_SHOW_TITLES` is enabled.
- **Zero hardcoded secrets:** none exist; none may be introduced.
- **Config variable names:** `WIDGET_REFRESH_MIN`, `WIDGET_SHOW_TITLES`, `LOG_LEVEL`.

---

## 8. Mandatory 5-Part Verification & Definition of Done

Write `tests/test_m5_widget_bridge.dart` using `flutter_test` and a **fake `WidgetHost`**. All five must pass.

- **Test 1 — Happy-Path Acceptance.** A valid push → `ok` with a `pushed_at`; the payload lands in the fake host.
- **Test 2 — Boundary & Idempotency Breaker.** A malformed payload → E1; a repeated push of the same payload is harmless (no error, no duplicate state).
- **Test 3 — Explicit Error-Shape Coverage.** One case each for E1, E7, E8 — exact `error.code` (E7/E8 driven by the fake host).
- **Test 4 — Registry Seam Contract Test.** OUT keys exactly `{pushed_at}` for push and `{route}` for tap; `route` is a non-empty string; `schema_version == 1`.
- **Test 5 — End-to-End Smoke & Health Probe.** Boots, pushes once, and routes a tap end to end.

**Definition of Done:** compiles; all 5 pass on Flutter 3.47.7; no secret literals; the module imports no widget plugin (only the port).

**Return format (Gate 5B Return Package)** — six sections: (1) ID + Version Stamp; (2) both paths; (3) `.env.example`; (4) pinned manifest + lockfile hash; (5) full contents of both files; (6) the 5-part receipt with **real `flutter test` output**.

---

## 9. Required Zero-AI Module Passport header

```
# ============================================================
# MODULE PASSPORT — M5 Widget Bridge
# Version Stamp : v1.0
# Module File   : src/modules/m5_widget_bridge.dart
# Test File     : tests/test_m5_widget_bridge.dart
# Registry Row  : MASTER_SYSTEM_DESIGN_DOCUMENT v1.2 (Table 2A, row M5)
# ------------------------------------------------------------
# SAFE TO EDIT  : private helpers, log messages, the deep-link
#                 route format
# DO NOT TOUCH  : the IN/OUT contract field names and types,
#                 the error codes, and the rule that M5 never
#                 queries the database (payload comes from M4)
# ============================================================
```
