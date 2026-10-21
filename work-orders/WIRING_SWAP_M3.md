# MINI WORK ORDER — WIRING-M3: swap the stand-in for the real M3 module

**Version Stamp: v1.0** · 2026-10-21 · Project: Reading Tracker ("Shelf")

## Why
M3 Progress Logger is **verified (v1.0, 5/5)** and sits in the repo, but `src/app/wiring.dart` still constructs the **temporary stand-in** `M1ProgressLogger` at two call sites. The app's progress path therefore still runs on the placeholder.

## The change
**File:** `src/app/wiring.dart`

1. Add a thin adapter so M3 satisfies the shell's `ProgressLoggerPort`:
   - `class M3ProgressLoggerAdapter implements ProgressLoggerPort` — delegates to `M3ProgressLogger.handle(...)` and maps M3's envelope to the port's shape.
2. Add a store adapter over M1:
   - `class M1ProgressStorePort implements ProgressStorePort` — forwards M3's write to M1's `update_progress`.
3. Provide a `Clock` implementation (the real system clock) for M3.
4. At **both** call sites — `wiring.dart` lines ~192 and ~233 — replace:
   ```
   progress: M1ProgressLogger(store),
   ```
   with the real module behind the adapter, e.g.:
   ```
   progress: M3ProgressLoggerAdapter(M3ProgressLogger(store: M1ProgressStorePort(store), clock: SystemClock())),
   ```
   (Confirm M3's exact constructor parameter names against `src/modules/m3_progress_logger.dart` before finalising.)
5. **Delete** the temporary `M1ProgressLogger` stand-in and its "M3 NOTE" comments. Keep `ProgressLoggerPort` if the shell still needs the seam; otherwise remove it too.

**Do not change** M3's module or its tests. Do not change any other module.

## Definition of done
- `src/app/wiring.dart` compiles and no longer references `M1ProgressLogger`.
- Re-run and paste the verbatim output of:
  - `flutter test tests/test_m3_progress_logger.dart`
  - `flutter test tests/test_integration_end_to_end.dart` (must stay 6/6)
- Write `receipts/WIRING-M3_receipt.md`, comment `DELIVERED WIRING-M3` on the task issue, and fire a `repository_dispatch` of type `builder-delivered`.
