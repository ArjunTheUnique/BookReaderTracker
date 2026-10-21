# INTEGRATION WORK ORDER — INT-1: App Shell, Port Wiring & End-to-End Test
**Order revision: v1.0**  ·  Date 2026-10-20  ·  Project: Reading Tracker ("Shelf")
This is **not** a module order — it is the integration order that turns the verified modules M1–M7 into one runnable app. Fully self-contained. The Stack Builder Agent sees only this document.

> Track note: M1 v1.0.2, M2 v1.0, M4 v1.0 VERIFIED. M3, M5–M7 in build. INT-1 depends only on the **frozen contracts** of all seven modules, so it can start once the last module's order is delivered — but its end-to-end test must run only when all seven are present.

---

## 0. Build prerequisites (unchanged)
Flutter **3.47.7** · Dart **3.13.5** · `dart run build_runner build` before `flutter test` · project name **`shelf_app`** · `build.yaml` mandatory · modules in `src/modules/`, tests in `tests/`. Dart rules: `part` after imports; narrow `Object?` to `String?`; `customSelect(...).getSingle()` → `QueryRow`. **Real `flutter test` output only (ADR-012).**

---

## 1. Identity

| Field | Value |
|---|---|
| Order ID | INT-1 |
| Version Stamp | v1.0 |
| Deliverables | `src/main.dart` · `src/app/app_shell.dart` · `src/app/routes.dart` · `src/app/wiring.dart` · `tests/test_integration_end_to_end.dart` |
| One-line purpose | Assemble the app: boot M1, wire every module through its port with the real adapters, render the 6×6 no-scroll shelf, and prove the whole chain works with one end-to-end test. |

---

## 2. What INT-1 assembles

The **composition root** (`src/app/wiring.dart`) is the single place where the real adapters are constructed and injected:

| Port | Real adapter (from the module edge files) | Module |
|---|---|---|
| `LibraryStorePort` | `M1LibraryStorePort` | M1 → M2, M3, M4, M6, M7 |
| `FileAccess` | `FilePickerFileAccess` | M2 |
| `PageExtractor` | `PdfEpubPageExtractor` | M2 |
| `Clock` | system clock | M3, M4 |
| `DailySourcePort` | adapter over M1 | M4 |
| `WidgetHost` | `home_widget` bridge | M5 |
| `FileVault` / `Cipher` | `dart:io` + `cryptography` | M6 |

No module may be imported by another module; only `wiring.dart` knows the concrete adapters.

---

## 3. The UI (the product's face)

`src/app/app_shell.dart` renders:

- **Home** — exactly **6 category tiles**, no vertical or horizontal scrolling. Each tile shows its name and its book count (0–6).
- **Category** — the tapped category's books (≤6), each tile showing the book title and **`pct_today`** (percentage of its pages read today).
- **Book** — one book's tile plus the "log progress" action (page entry → M3).
- **Add a book** — the M2 intake flow (device file or manual).
- **Settings** — the daily goal (`DEFAULT_DAILY_GOAL_PAGES`), backup export/import (M6).

**Data source:** the shell reads **view-models from M7 only** (`home` / `category` / `book`). It never queries the database or computes a percentage itself.

**The `goal_pages` wiring (resolves M4 finding F3):** the shell reads the daily goal from settings and passes it to **M5** when pushing the widget payload. M4 supplies `total_pages_today` and `per_book`; M5 supplies nothing but the push. Do not look for the goal in M4's output.

---

## 4. Routing & deep links

`src/app/routes.dart` maps the widget's tap route (from M5) to the right screen: `shelf://book/<id>` → the book view; `shelf://category/<id>` → the category view. A cold start from a widget tap must land on the correct screen after M1 boots.

---

## 5. Failure & security guards

- **Boot health (C1):** on launch, open M1, run the seed if empty, and run the health probe. If the probe is not `"ok"`, show a restore prompt (M6) rather than a broken grid.
- **Permission fallback:** a refused file permission degrades to manual book entry; never crash.
- **Zero hardcoded secrets:** none exist; none may be introduced. Settings values are non-secret.

---

## 6. Mandatory End-to-End Verification (the definition of done)

Write `tests/test_integration_end_to_end.dart` using `flutter_test` and an **in-memory M1**. One suite that drives the whole chain through the wiring:

- **E2E-1 — Add and see.** Add a book via M2 → the home grid (M7) shows it in the right category.
- **E2E-2 — Log and reflect.** Log progress via M3 → the day view (M4) shows the right `total_pages_today` and `pct_today`, and the book tile reflects it.
- **E2E-3 — Widget payload.** Assemble the push payload (M4 day view + shell goal) → M5 accepts it and the fake `WidgetHost` receives `goal_pages`, `total_pages_today` and `per_book_pct`.
- **E2E-4 — Tap routing.** A widget tap route resolves to the correct screen.
- **E2E-5 — Backup round-trip.** Export via M6 → wipe → restore → the grid is identical.
- **E2E-6 — The 6×6 wall.** A 7th category and a 7th book both fail with E3, surfaced cleanly to the UI.

**Definition of Done:** the app **compiles and builds**; the end-to-end suite passes on Flutter 3.47.7 with real `flutter test` output; every module is reached only through its port; no module imports another module directly; no secret literals.

**Return format:** the six-section package as before, with section 5 carrying the full contents of the five INT-1 files and section 6 the real execution receipt.

---

## 7. Passport header

```
# ============================================================
# INTEGRATION PASSPORT — INT-1 App Shell & Wiring
# Version Stamp : v1.0
# Files: src/main.dart · src/app/app_shell.dart · src/app/routes.dart
#        src/app/wiring.dart · tests/test_integration_end_to_end.dart
# ------------------------------------------------------------
# SAFE TO EDIT  : layout, colours, copy, tile sizes
# DO NOT TOUCH  : the wiring table in §2, the goal_pages source
#                 (§3), the routes in §4, and the rule that the
#                 UI reads view-models from M7 only
# ============================================================
```
