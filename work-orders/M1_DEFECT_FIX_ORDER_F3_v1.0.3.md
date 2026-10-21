# DEFECT FIX ORDER — M1 Library Store (finding F3)
**Failed Version Stamp: v1.0.2 → Target Patched Version Stamp: v1.0.3**
Issued at Gate 5B (M2 audit) · Date 2026-10-19 · Project: Reading Tracker ("Shelf")

Source: finding **F3** raised by the Stack Builder while building M2. The Builder worked around it in M2; this order fixes it at the root in M1. This order is fully self-contained.

---

## 1. Identity

| Field | Value |
|---|---|
| Module ID | M1 |
| Failed Version Stamp | v1.0.2 |
| Target Patched Version Stamp | v1.0.3 |
| Target Module File Path | `src/modules/m1_library_store.dart` |
| Target Test File Path | `tests/test_m1_library_store.dart` |

---

## 2. Exact failed behaviour

**M1's `add_book` idempotency replay does not return the original result.** The contract (Registry row M1; work order §4) says a repeated `idempotency_key` is a silent no-op that "returns success". In practice, `_replayIfSeen` recognises the key but then looks the book up using the `book_id` **in the incoming payload**. If a caller retries with a different `book_id`, the lookup misses and M1 returns **E4 (NOT_FOUND)** — contradicting its own contract.

## 3. Expected vs. Actual

| Scenario | Expected (per contract) | Actual (v1.0.2) | Delta |
|---|---|---|---|
| `add_book` key K for book A succeeds; then `add_book` key K for book B | success (no-op replay of A) | `E4 NOT_FOUND` | wrong result |
| `add_book` key K for the same book A twice | success, added once | success, added once | OK |
| `update_progress` key K twice | `saved:false`, one row | `saved:false`, one row | OK |

Only the **cross-payload replay** case is broken; same-payload replay and progress replay are fine.

## 4. Root-cause & boundary diagnosis

The idempotency ledger stores only `{op, idempotencyKey, createdAt}`. On replay it must reconstruct the original outcome, but it has nothing to reconstruct it *from* — so it falls back to the incoming payload's `book_id`, which may differ. The ledger is a **guard**, not a **record of the result**. The fix is to make the ledger remember what the first call produced.

## 5. Corrected specification & exact fix directive

1. Add a nullable `resultRef` column to the `IdempotencyLedger` table (e.g. `TextColumn get resultRef => text().nullable()();`) — it will hold the `book_id` that the first `add_book` created. Bump `kSchemaVersion` to 2 and add a Drift migration (`onUpgrade`) that adds the column. **This is a Registry-relevant change: update the Master Doc's schema note and flag every module that calls M1.**
2. In `_addBook`, when writing the ledger row, store `resultRef = bookId` (the book actually created).
3. In `_replayIfSeen` for `add_book`, return the result derived from `resultRef` (the original book), **ignoring** the incoming payload's `book_id`. Do not look up by the incoming id.
4. Keep the same-payload and `update_progress` behaviour exactly as it is — both are already correct.
5. Bump both Module Passports to **v1.0.3**.

## 6. Full regression re-run mandate

After the fix, re-run **all five** M1 tests — Tests 1–5 — **plus a new Test 2 case**: call `add_book` with key K and book A (success), then call `add_book` with the **same key K but a different book B**, and assert it returns the original success (book A), not E4. Then return the complete 6-section Gate 5B package at **v1.0.3** with real `flutter test` output.

The Architect will independently re-run M1 v1.0.3 before accepting it.
