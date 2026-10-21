# Request to the Architect — issue the M3 (Progress Logger) work order

## Status
M3 (Progress Logger) has **never been delivered** to the Stack Builder. No MODULE WORK ORDER
for M3 appears in any handover to date. The modules received so far are **M1, M2, M4, M5, M6,
M7**, plus the integration orders **INT-1** and **INT-2**.

## Why it matters
INT-1's composition root and the app shell both need M3 for the "log progress" path. So the
whole chain could be verified end to end, the Builder wired a clearly-labelled
`ProgressLoggerPort` in `src/app/wiring.dart` with a **temporary M1-backed stand-in**
(`M1ProgressLogger`) that logs straight through M1's `update_progress` in M3's shape.
INT-1's E2E-2 exercises that seam and passes — but the **real M3 module does not exist**.
Until it does, the app's progress path runs on a placeholder.

## What to send
A MODULE WORK ORDER for M3 carrying all nine mandatory items:

1. Module ID, Version Stamp, Target Module File Path & Filename, Target Test File Path &
   Filename (expected: `src/modules/m3_progress_logger.dart` and
   `tests/test_m3_progress_logger.dart`)
2. Tech Stack & Pinned Versions
3. Verbatim Central Interface Registry row for M3
4. Machine Input Socket Contract
5. Machine Output Socket Contract & Error Shapes
6. Control Switches & Data Pipes
7. Failure, Idempotency & `.env` Guards
8. 5-Part Verification Suite Specs
9. Module Passport Header Format

## Already known — from the Master System Design Document v1.1 (Table 2A)
The registry row for M3 already exists, so the order can be short:

| ID | Job | Machine Input | Machine Output | Errors |
|---|---|---|---|---|
| M3 | Progress Logger | {book_id,current_page,read_on,idempotency_key} | {ok,book_id,current_page,pct_read,saved} | E1,E2,E4,E5 |

M3 is expected to be a **thin** module: validate the progress input, then write through M1's
`update_progress`, passing the idempotency key straight through so a repeated key never
double-counts. The order should still state the exact boundary rules, the config variable
names, and the five test specs.

## What the Builder will do on receipt
Audit the order against all nine items; build `src/modules/m3_progress_logger.dart` in the
four-zone layout with a Zero-AI passport; write the five-part suite; run it on Flutter 3.47.7;
**replace INT-1's stand-in with the real module**; and re-run the end-to-end suite to prove
no regression.

## Note on the build prerequisites
M3 needs no platform packages — it writes only through M1 — so it should need no adapter
file and no new dependency. Standard prerequisites still apply: Flutter 3.47.7, Dart 3.13.5,
`dart run build_runner build` before `flutter test`, project name `shelf_app`, and the
committed `build.yaml`.
