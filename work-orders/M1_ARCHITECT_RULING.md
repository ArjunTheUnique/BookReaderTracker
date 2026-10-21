# M1 LIBRARY STORE — ARCHITECT RULING & MANIFEST CORRECTION
Issued at Gate 5B (third pass) · Date 2026-10-19 · Project: Reading Tracker ("Shelf")
Scope: respond to the operator's M1 Project Status; correct the work order's pins; rule on the A/B/C decision.

---

## 1. First, my error — owned

Two of the pins in my work order were wrong, and that is the root cause of two of the setup failures:

- I pinned **`drift_dev 2.35.2`**. That version is not published; the real one is **2.35.1**.
- I pinned **`build_runner 2.17.1`**. It resolved to **2.16.2**.

What I did wrong: I read `drift 2.35.2` off the registry and **assumed its codegen companion `drift_dev` shares the same version line.** It does not. I also asserted a `build_runner` version I had not verified. Both were my mistakes, not the builder's, and not Flutter's.

This is now a process rule (see §7): **never assume a package and its companion share a version — verify every pin exists, individually, before it goes in an order.**

---

## 2. Corrected pinned manifest (authoritative — supersedes the v1.0 Master Doc table)

```yaml
name: shelf_app                 # NOT "shelf" — clashes with the published `shelf` library build_runner needs
description: Local-first reading tracker ("Shelf").
publish_to: "none"
version: 1.0.1+1

environment:
  sdk: ">=3.10.0 <4.0.0"
  flutter: "3.47.7"             # stable, installed on the operator's machine

dependencies:
  flutter:
    sdk: flutter
  drift: 2.35.2                 # verified present
  sqlite3_flutter_libs: 0.5.42  # DELIBERATE PIN — see §3
  path_provider: 2.1.6          # verified

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: 2.35.1             # CORRECTED from 2.35.2 (not published)
  build_runner: 2.16.2          # CORRECTED from 2.17.1
```

| Package | Section | Final pin | Why |
|---|---|---|---|
| `drift` | dependencies | `2.35.2` | exists as published |
| `sqlite3_flutter_libs` | dependencies | `0.5.42` | deliberate pin; `0.6.0+eol` is a retired no-op (§3) |
| `path_provider` | dependencies | `2.1.6` | resolved cleanly |
| `drift_dev` | dev_dependencies | `2.35.1` | **corrected** — `2.35.2` is not published |
| `build_runner` | dev_dependencies | `2.16.2` | **corrected** — `2.17.1` was wrong |

The module **code** does not change. `src/modules/m1_library_store.dart` stays at **v1.0.1**; only the build manifest is corrected, so the Version Stamp does not move.

---

## 3. Ruling: pin `sqlite3_flutter_libs` to `0.5.42`

This is the most important finding in your status, and it is not just a test problem.

`sqlite3_flutter_libs` resolved to **`0.6.0+eol`** — a version whose code has been removed. It bundles **nothing**. If the app ships against it, the database has **no SQLite engine** at runtime: M1 would open fine in a test but fail in the real app. So:

- **Pin `0.5.42` explicitly.** Never let this package resolve automatically — "latest" is currently a trap.
- Treat the package as **at-risk / unmaintained**: watch it, and if a maintained replacement appears, that becomes an ADR (it sits behind M1's socket, so swapping it is contained).

---

## 4. The `build_runner` blocker — diagnose before you fix

**Step 0, before anything else: check whether code generation already succeeded.**

```
dir src\modules\m1_library_store.g.dart
```

If that `.g.dart` file **exists**, `build_runner` actually ran and the "terminal closing" is cosmetic — you can skip straight to the test (§6, step 3). This is the fastest way to know.

If it does **not** exist, capture the output to a file so it cannot vanish:

```
cd shelf_app
dart run build_runner build --delete-conflicting-outputs > br.log 2>&1
type br.log
```

If the window still closes with an empty or truncated log, try, in order:
1. Run from a **plain PowerShell or cmd** window, not an IDE terminal or a wrapper that closes on child exit.
2. `flutter pub run build_runner build --delete-conflicting-outputs > br.log 2>&1`
3. `dart run build_runner build --delete-conflicting-outputs --verbose > br.log 2>&1` — the verbose log will name the real failure if it is a crash rather than a cosmetic exit.

Most likely causes, in order: a shell wrapper closing on child exit (cosmetic), an unhandled error from the wrong `drift_dev` version (§2 — likely now fixed), or antivirus interfering with the codegen file writes.

---

## 5. Ruling on Options A / B / C — **choose A**

**A — push ahead with Flutter. Recommended.**

The reasoning is about what you actually asked for at Gate 0, not about the toolchain:

1. **The product is a cross-platform mobile app** — Android **and** iPhone, published for many users. That requirement *needs* a cross-platform framework, and Flutter was crowned at Gate 4 against your own weights (Low-Maintenance at 40% → one codebase instead of two). Options B and C do not fix the verification blocker — they **change the product's stack**, which means reopening Gate 0 and re-running Gates 3–4. That is a far bigger move than the problem warrants.
2. **Every failure so far is setup, not design.** Missing SDK (now installed and green), two wrong pins (mine, corrected in §2), a name clash (fixed by `shelf_app`), and a terminal quirk (§4). None of these is a fault in the architecture, the module, or Flutter.
3. **The remaining work is small** — by your own estimate, an hour or two.
4. Dropping Flutter to escape a Windows terminal bug would be solving the wrong problem, and would discard reviewed, working code.

**B (drop Flutter) / C (hybrid rewrite)** are legitimate *only* as product decisions — "I do not want to maintain a Flutter environment at all." If that is genuinely how you feel, say so plainly and I will reopen Gate 0, re-score the stack with the same weights, and re-issue the work orders for the new stack. But do not choose B or C as a workaround for a setup bug; that is a large, expensive answer to a small, unfinished task.

---

## 6. Exact remaining steps (Option A)

1. Fix the manifest to §2 (`shelf_app`, `drift_dev 2.35.1`, `build_runner 2.16.2`, `sqlite3_flutter_libs 0.5.42`).
2. Diagnose `build_runner` per §4. Confirm `src/modules/m1_library_store.g.dart` exists.
3. If the test then complains about a missing `sqlite3.dll` (a known Windows quirk — `flutter test` runs on the host, where `sqlite3_flutter_libs` does not supply the DLL): fetch `sqlite3.dll` and place it where the test runner can find it (project root or on `PATH`). This is expected and solvable, not a sign of a deeper fault.
4. Run the suite and capture the output to a file so it cannot vanish:
   ```
   flutter test --reporter expanded tests\test_m1_library_store.dart > test.log 2>&1
   type test.log
   ```
5. Return the completed 6-section Gate 5B package at **v1.0.1**, with **Section 4** updated to the corrected manifest and **Section 6** replaced by the real `test.log` output.

---

## 7. Process fix so this cannot recur (for the Master Doc, next revision)

**ADR-010 — Verify every pin individually; never infer a companion's version.**
Decision: before any version enters a work order or a manifest, confirm that exact version is published for that exact package. A package and its codegen/companion are independent release lines. Corollary: pin native-plugin packages explicitly (see `sqlite3_flutter_libs`), because "latest" can be a retired no-op.

**ADR-011 — The verification machine must be declared.**
Decision: every work order that demands an execution receipt must state the required toolchain (Flutter 3.47.7 + a host `sqlite3.dll` on Windows) and the ordering (`build_runner` before `flutter test`), so a missing toolchain is never mistaken for a code defect.

Both land in the Master System Design Document when it is re-issued at M1's pass (all four documents increment together, per the version-sync rule). Until then, **the v1.0 Master Doc's manifest table is superseded by §2 above.**
