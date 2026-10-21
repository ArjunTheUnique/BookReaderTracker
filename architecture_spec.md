# Book Reader Tracker — Architecture Specification

**Version:** v1.4
**Last updated:** 2026-10-21
**Source:** Gate 4 Master System Design Document, revised through the Gate 5B module audits

> This is the canonical, versioned home of the finalized design. It is plain Markdown on purpose, so it stays readable and hand-editable years from now with no AI.

## Change log
- v1.4 (2026-10-21) — M3 verified; INT-1 v1.0.1 verified (compiles; e2e 6/6). Wiring swap from the temporary M1ProgressLogger stand-in to the real M3 module is outstanding.
- v1.3 (2026-10-21) — M4 verified; EPUB pagination locked (ADR-016); integration workstream defined (ADR-017); `goal_pages` source clarified; corrected pins confirmed by real builds.
- v1.2 (2026-10-20) — M1 v1.0.2 and M2 v1.0 verified; ADR-014 (idempotent replay) and ADR-015 (injectable ports) added.
- v1.1 (2026-10-19) — M1 v1.0.2 verified; corrected pins; build.yaml requirement; ADR-010…013 added.
- v1.0 (2026-10-19) — first issue at Gate 4.

---

## 1. Product

A reading tracker whose home screen never scrolls: exactly **6 categories**, each holding at most **6 books**, every book tile showing the **percentage of its pages read today**. Books are device ebooks (PDF/EPUB) or offline books logged by hand. A home-screen **widget** shows pages read today against a daily goal. **All data lives on the user's own device** — no server, no accounts.

**Platform:** Android only. iOS is dropped by operator decision (it needs macOS plus a paid Apple Developer account, against the ₹0 and no-local-work walls).

## 2. Hard walls (never crossed without a version bump)

- Budget: ₹0/month — free and open-source only, no paid servers.
- No server, no accounts: every byte stays on the device.
- Exactly 6 categories; at most 6 books each; the home grid never scrolls.
- Zero hardcoded secrets; all configuration is a value, never a credential.
- No work on the operator's machine — everything runs in a Builder or Architect sandbox.

## 3. Master folder & file tree

```
shelf_app/                      # root package name MUST be shelf_app (never `shelf`)
  build.yaml                    # MANDATORY: registers src/** and tests/** for build_runner
  pubspec.yaml / pubspec.lock   # exact pins / the authoritative lockfile
  src/
    modules/                    # production modules
      m1_library_store.dart
      m2_book_intake.dart
      m3_progress_logger.dart
      m4_daily_engine.dart
      m5_widget_bridge.dart
      m6_backup_vault.dart
      m7_grid_presenter.dart
      *_adapters.dart           # platform edge: the only place platform packages appear
    app/
      main.dart · app_shell.dart · routes.dart · wiring.dart   # INT-1 composition root
  tests/
    test_m1_library_store.dart … test_m7_grid_presenter.dart
    test_integration_end_to_end.dart
```

**Build requirement:** `src/` and `tests/` are outside the folders Dart's build tooling scans by default (`lib/`, `test/`). Without the committed `build.yaml`, drift's generator silently writes ZERO outputs and the module then fails to compile with `part '....g.dart' not found`.

## 4. Central Interface Registry (frozen contracts)

| ID | Job | Machine Input | Machine Output | Errors |
|---|---|---|---|---|
| M1 | Library Store — source of truth | `{op,payload,idempotency_key,schema_version}` | `{ok,data,schema_version}` | E1,E2,E3,E4,E5,E7 |
| M2 | Book Intake | `{category_id,source,file_uri?,title,total_pages?,cover_ref?}` | `{ok,book_id,category_id,total_pages,source}` | E1,E2,E3,E4,E6,E7,E8 |
| M3 | Progress Logger | `{book_id,current_page,read_on,idempotency_key}` | `{ok,book_id,current_page,pct_read,saved}` | E1,E2,E4,E5 |
| M4 | Daily Engine | `{as_of_date,timezone_offset_min}` | `{ok,date,total_pages_today,per_book[]}` | E1,E2,E4 |
| M5 | Widget Bridge | push `{goal_pages,total_pages_today,per_book_pct[]}` / tap `{target_type,target_id}` | `{ok,pushed_at}` / `{ok,route}` | E1,E7,E8 |
| M6 | Backup Vault | export `{destination_uri,passphrase}` / restore `{source_uri,passphrase}` | `{ok,bytes,schema_version,checksum}` | E1,E7,E9 |
| M7 | Grid Presenter | `{view,category_id?,book_id?}` | `{ok,categories[] (len 6)}` | E1,E4 |

Shared error shape: `{ok:false, error:{code, message, field?}}`. E1 INVALID_INPUT · E2 OUT_OF_RANGE · E3 LIMIT_EXCEEDED · E4 NOT_FOUND · E5 DUPLICATE · E6 UNSUPPORTED_FORMAT · E7 STORAGE_ERROR · E8 PERMISSION_DENIED · E9 BACKUP_INVALID.

## 5. Wiring

M7 renders view-models read from M1/M4 (never writes). M2, M3, M5, M6 sit above M4, which sits above M1 — the only component that touches the database. Storage is three local stores: the SQLite file, app-private files (ebooks + `.rtbk` backups), and the shared widget store. Modules never import each other; only `src/app/wiring.dart` (INT-1) knows the concrete adapters.

**`goal_pages` source:** the app shell supplies it (the user's setting). M4 supplies `total_pages_today` and `per_book`; M5 supplies nothing but the push.

## 6. Winning stack & pinned dependencies

| Layer | Package | Pin |
|---|---|---|
| SDK | Flutter | 3.47.7 (stable) · Dart 3.13.5 |
| Database | drift | 2.35.2 |
| Database codegen | drift_dev | **2.35.1** (2.35.2 is not published) |
| Native sqlite | sqlite3_flutter_libs | **0.5.42** (deliberate; 0.6.0+eol is a retired no-op) |
| Paths | path_provider | 2.1.6 |
| Parser | pdfx | 2.11.0 · epubx 4.0.0 (stale — isolated behind M2's socket) |
| File picking | file_picker | 13.1.0 |
| Widget | home_widget | 0.10.0 |
| Crypto | cryptography | 2.9.0 · cryptography_flutter 2.3.4 |
| Codegen runner | build_runner | 2.16.2 |

## 7. Architecture Decision Records

- **ADR-001** One Flutter codebase, not native Kotlin+Swift (Low-Maintenance 40%).
- **ADR-002** Local-first, no server, no accounts.
- **ADR-003** SQLite via Drift over raw sqflite.
- **ADR-004** pdfx + epubx, isolated behind M2's socket.
- **ADR-005** home_widget for the widget bridge.
- **ADR-006** cryptography (AES-256-GCM) for backups.
- **ADR-007** Idempotency keys on every state-changing write.
- **ADR-008** The 6×6 caps are enforced in the store, not the UI.
- **ADR-009** One error shape (E1–E9) across all modules.
- **ADR-010** Verify every pin individually; never infer a companion's version.
- **ADR-011** Every execution order must declare its toolchain.
- **ADR-012** Real execution is mandatory; simulation is not evidence.
- **ADR-013** Pin native plugin packages explicitly.
- **ADR-014** Idempotent replay must return the ORIGINAL result (finding F3).
- **ADR-015** Platform packages live behind injectable ports (finding F1).
- **ADR-016** EPUB pagination locked: spine-item count.
- **ADR-017** Turning verified modules into a runnable app is its own workstream.

## 8. Verification status

| Item | State |
|---|---|
| M1 Library Store | **VERIFIED v1.0.2** (5/5, independently reproduced) — open fix order F3 → v1.0.3 |
| M2 Book Intake | **VERIFIED v1.0** (5/5, independently reproduced) |
| M3 Progress Logger | **VERIFIED v1.0** (5/5, independently reproduced) — wiring swap to the real module outstanding |
| M4 Daily Engine | **VERIFIED v1.0** (5/5, independently reproduced) |
| M5 Widget Bridge | **VERIFIED v1.0** (5/5, independently reproduced) |
| M6 Backup Vault | **VERIFIED v1.0** (5/5, independently reproduced) |
| M7 Grid Presenter | **VERIFIED v1.0** (5/5, independently reproduced) |
| INT-1 App Shell | **VERIFIED v1.0.1** (compiles; end-to-end 6/6, independently reproduced) |
| INT-2 Widget & Packaging | Sources delivered; **APK not built** (no Android SDK) |

**The verification rule:** every module is checked twice — read against its contract, and its tests re-run in a second, independent environment. A receipt that cannot be reproduced is a claim, not evidence.
