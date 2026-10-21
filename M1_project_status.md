# M1 Library Store — Project Status (for Architect discussion)

Prepared: 2026-10-19
Project: Reading Tracker ("Shelf") — local-first, no server, no accounts
Module: M1 Library Store — target version v1.0.1
Purpose of this page: a plain, honest picture so a decision can be made — push ahead with Flutter, or drop it.

---

## 1. Verdict in one line

The M1 code is **finished and internally verified**; the only thing outstanding is
**running the Dart test suite on the operator's PC**, and that is blocked by
**environment/setup issues — not by the code and not by a design fault.**

In other words: nothing is wrong with the module. The obstacle is the local Flutter
toolchain and a handful of incorrect details in the work order.

---

## 2. Where M1 actually stands

| Area | Status |
|---|---|
| M1 module code (`src/modules/m1_library_store.dart`) | DONE — v1.0.1, four zones, passport, Fix C applied |
| Test file (`tests/test_m1_library_store.dart`) | DONE — five tests plus a Fix C regression case |
| Logic verification (rules-only parity harness) | 26 / 26 PASS — but this is NOT the Dart suite |
| Pinned dependency manifest | DONE on the operator's machine, using real versions |
| Real `flutter test` execution receipt | BLOCKED — the suite has not run yet |
| Gate 5B return package | Delivered as INCOMPLETE at v1.0.1 |

So: roughly "code complete, verification incomplete."

---

## 3. What is already finished (builder side)

- M1 module at v1.0.1 with the Defect Fix Order's **Fix C** applied: the idempotency
  ledger primary key is now the composite `{op, idempotencyKey}`, so a key string reused
  across two different operations is no longer mis-read as a replay.
- Test file updated with a regression case that proves Fix C (it fails against the old
  single-column key, passes against the new one).
- A rules-only parity harness (Python + SQLite) passes 26/26 — useful corroboration of
  the boundary rules, control switches and data pipes, but it is **not** the Dart code
  compiling or running.
- Six-section Gate 5B package delivered at v1.0.1, with the runtime rows honestly marked
  INCOMPLETE rather than PASS.

---

## 4. What happened on the operator's machine (setup timeline)

1. **Flutter was not installed.** Installed Flutter 3.47.7 (stable) and Dart 3.13.5.
   `flutter doctor` is green for Flutter, Dart, Windows, Chrome and Visual Studio. The
   only red item is the Android toolchain — irrelevant for running unit tests.
2. **`flutter pub get` failed: `drift_dev 2.35.2` does not exist.** The order's pinned
   version is not published on the registry, so resolution stopped. Fixed by letting
   Flutter choose the real versions, then reading them back.
3. **Project name clash.** The project was first created as `shelf`, but a published
   library called `shelf` is required by `build_runner`, so two packages shared a name and
   resolution failed. Fixed by renaming the project to `shelf_app`.
4. **Code generation will not run.** `dart run build_runner build` closes the terminal
   window instead of printing its result. Not yet diagnosed.

---

## 5. Environment findings — where the order's versions were wrong

| Package | Order asked for | What actually resolved | Note |
|---|---|---|---|
| drift | 2.35.2 | **2.35.2** | exists — fine |
| drift_dev | 2.35.2 | **2.35.1** | 2.35.2 is not published |
| sqlite3_flutter_libs | "from pubspec.lock" | **0.6.0+eol** | retired/empty version — bundles nothing |
| path_provider | "from pubspec.lock" | **2.1.6** | fine |
| build_runner | "from pubspec.lock" | **2.16.2** | fine |

Two of these matter beyond the test run:

- **`sqlite3_flutter_libs` resolved to `0.6.0+eol`**, a version that has had its code
  removed and does nothing. The real app will therefore not bundle the SQLite library.
  This will need a deliberate pin to the last working version (e.g. `0.5.42`) before the
  app can ship — a decision for the Architect.
- **`drift_dev` must be `2.35.1`**, not `2.35.2`.

---

## 6. The single remaining blocker

`dart run build_runner build --delete-conflicting-outputs` closes the terminal instead of
completing. This step must succeed before any test can run, because it generates the
`m1_library_store.g.dart` helper file the module depends on.

Status: **not yet diagnosed.** A capture-to-file workaround (writing the command's output
to a text file so it cannot vanish) was provided but has not been attempted yet.

One further known risk sits just behind it: because the SQLite plugin resolved to the
empty `0.6.0+eol` version, the test may additionally need a `sqlite3.dll` file placed by
hand. That is a known, solvable Windows quirk, but it is one more step.

---

## 7. Decision options

### Option A — Push ahead with Flutter (recommended if the product stays Flutter)
- **What it costs:** one debugging session on the `build_runner` terminal issue, then one
  test run. Realistically an hour or two, not days.
- **Why it is close:** Flutter is already installed and working; dependencies are pinned;
  the project skeleton exists. The remaining work is small and mechanical.
- **Risk:** the SQLite DLL step may add one extra fix. The `sqlite3_flutter_libs` pin
  needs a decision regardless.
- **Best if:** the app itself is meant to be Flutter (mobile/desktop), or you want the
  verification path the order already assumes.

### Option B — Drop Flutter
- **What it costs:** the M1 module is Dart/Flutter-specific (drift + sqlite3). Removing
  Flutter means rewriting M1 in another stack and re-verifying from scratch. That is a
  large change, not a small one, and it discards working, reviewed code.
- **Why you might still choose it:** if you have no intention of maintaining a Flutter
  environment, or the product's real target is not Flutter at all.
- **Best if:** Flutter was only ever a means to an end and that end can be met more simply
  (for example, a pure-Dart or a non-Dart stack that runs in a lighter environment).

### Option C — Hybrid
- Keep the M1 **design** (socket contract, zones, rules, error shapes) — which is the
  valuable, portable part — and re-implement only the storage layer in a stack that is
  easier to run and verify on this machine.
- **Cost:** a moderate rewrite of the module internals; the contract survives untouched.
- **Best if:** you want to keep the architecture but stop fighting the toolchain.

**Fair summary:** every failure so far has been a *setup* problem, not a sign that Flutter
is the wrong choice. Dropping Flutter is a big, expensive answer to what is currently a
small, unfinished task. But if you do not want a Flutter environment at all, that is a
legitimate reason to choose Option B or C, and it is better decided now than after more
time is spent.

---

## 8. If you push ahead: the exact remaining steps

1. Fix the `build_runner` terminal-closing issue (start with the capture-to-file
   workaround; paste the saved log).
2. If the test then complains about `sqlite3.dll`, fetch the Windows SQLite DLL and place
   it where the test can find it.
3. Run the suite: `flutter test tests/test_m1_library_store.dart`.
4. Paste the verbatim output as the real execution receipt.
5. Return the completed 6-section Gate 5B package at v1.0.1.

---

## 9. What the Architect should change in the order regardless of the decision

- Correct the pins: `drift_dev` 2.35.1 (not 2.35.2); record the real resolved versions for
  `path_provider` (2.1.6) and `build_runner` (2.16.2).
- Decide the `sqlite3_flutter_libs` pin deliberately — `0.6.0+eol` is a no-op and will
  break the real app; the last working version is `0.5.42`.
- Note that the project name must not be `shelf` (clash with a library `build_runner`
  depends on); `shelf_app` works.
- Add a line acknowledging that the verification machine must have Flutter installed and
  that `build_runner` must run before `flutter test`.
