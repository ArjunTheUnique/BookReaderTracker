# Handoff Protocol — Book Reader Tracker

**Purpose:** the Architect and the Stack Builder share this repo. This folder is the mailbox, so work moves without a human relaying files. Read this once; follow it every time.

Version: v1.1 · 2026-10-21

---

## The two surfaces

1. **The queue — `handoff/queue.json`** (machine-readable).
   The **Architect writes work here**. Each item has an `id`, a `title`, the `order` file to build from, a `status`, and a `receipt` path.

2. **The trigger — a GitHub Issue labelled `builder-task`.**
   Opening one is the **"you have work"** signal. Nothing else is needed.

## Status vocabulary (use exactly these words)

| Status | Meaning |
|---|---|
| `OPEN` | work defined, not started |
| `IN_PROGRESS` | Builder is on it |
| `DELIVERED` | Builder finished; receipt written; awaiting audit |
| `VERIFIED` | Architect audited and passed |
| `BLOCKED` | cannot proceed — reason in `note` |

## Rules

- **The Architect never edits `src/` or `tests/` directly.** It writes orders, the queue, and issues.
- **The Builder never invents work.** It takes the next `OPEN` item from the queue.
- The Builder writes its output to **`receipts/<id>_receipt.md`** and comments **`DELIVERED <id>`** on the issue.
- The Architect audits `receipts/`, then either flips the status to `VERIFIED` or opens a **Defect Fix Order** and sets the item back to `OPEN`.
- **Every claim carries its receipt.** A status of `DELIVERED` without a receipt file is not delivered.

## Verification depth — how deep the Architect's check goes

The Architect checks by **re-running**, not by reading. Depth (operator's choice, 2026-10-21):

- **Default:** re-run **only what changed** — the newly delivered module's suite — **plus the end-to-end suite**. That catches both a broken module and a broken seam.
- **Full-chain** re-run is reserved for milestones: a version bump, or the final packaging run.
- A receipt that cannot be reproduced is a claim, not evidence. (This check has already caught five real defects that "all tests passed" receipts hid.)

## The trigger chain

```
Architect  → adds item to handoff/queue.json  (status OPEN)
           → opens a GitHub issue labelled "builder-task"  (or fires repository_dispatch: architect-ready)
                 │
GitHub     → .github/workflows/handoff.yml fires
           → comments the task, and (if BUILDER_WEBHOOK_URL is set) POSTs a ping to the Builder
                 │
Builder    → reads the issue + the queue, builds the order, writes receipts/<id>_receipt.md
           → comments "DELIVERED <id>"  → fires repository_dispatch: builder-delivered
                 │
Architect  → audits (changed suite + end-to-end), flips the status to VERIFIED, reports
```

## Setting up the instant ping (optional)

The issue alone is a trigger if the Builder watches issues. For an **instant** ping, add a repo secret:

- Name: `BUILDER_WEBHOOK_URL` · Value: the Builder's endpoint URL.

Without the secret, the workflow logs a clear warning and exits cleanly — nothing breaks.

## The scheduled audit (safety net)

The Architect also runs on an **hourly schedule** as a backstop, checking for anything marked `DELIVERED`. So: build, write the receipt, comment — and it will be picked up even if the event is missed.
