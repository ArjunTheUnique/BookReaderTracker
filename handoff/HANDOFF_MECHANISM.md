# How you and the Builder now talk — no more relaying files

Plain English. Date: 2026-10-21.

## The problem you had

You and I share one repo, but every hand-off went through you: I made a file → you carried it to the Builder → you carried its answer back. That is slow and error-prone.

## What I built — a mailbox with a doorbell

**The mailbox** (a `handoff/` folder in the repo):
- **`handoff/queue.json`** — the list of jobs, machine-readable. Each job has an id, the file to build from, and a status: `OPEN → IN_PROGRESS → DELIVERED → VERIFIED` (or `BLOCKED`).
- **`handoff/PROTOCOL.md`** — the rules both sides follow, so we speak the same language.

**The doorbell** (a GitHub Issue):
- When there's work, I open an **issue labelled `builder-task`**. That is the signal. Opening it fires the workflow, which comments the task and — if you set a webhook — pings the Builder instantly.
- **Issue #1 is already open: "M3 Progress Logger".** That is the live trigger right now.

**The workflow** (`.github/workflows/handoff.yml`): fires on a new task issue or a queue update. It comments the task, and if a repo secret `BUILDER_WEBHOOK_URL` exists, POSTs a ping to the Builder. With no secret, it just comments — nothing breaks.

**My side, automatic:** I am now on an **hourly schedule**. Each hour I check the repo for anything marked `DELIVERED`, audit it, flip the status to `VERIFIED` (or send back a fix order), and report. So once the Builder writes its receipt, it gets picked up **without you doing anything**.

## The loop, end to end

```
I open a task issue  →  the workflow comments + pings  →  the Builder builds
        ↑                                                        │
        └──── I audit hourly and flip the status ←── the Builder writes its receipt
```

## The one thing you need to do

**Make sure the Builder watches this repo's issues** (or set the webhook so it gets pinged):
- If the Builder is a GitHub-aware agent: tell it to **watch issues labelled `builder-task`** in `ArjunTheUnique/BookReaderTracker`.
- If the Builder has a webhook/endpoint: add a repo secret named **`BUILDER_WEBHOOK_URL`** with that URL, and the workflow will ping it on every new task.

Either one closes the loop. You then only need to look in when a verdict lands.

## What is live right now

| Thing | State |
|---|---|
| Mailbox (`handoff/PROTOCOL.md`, `handoff/queue.json`) | ✅ in the repo |
| Workflow (`.github/workflows/handoff.yml`) | ✅ in the repo |
| Trigger issue #1 — M3 Progress Logger | ✅ open, labelled `builder-task` |
| My hourly audit schedule | ✅ enabled (next run 12:00 IST) |

## The two open jobs

- **`M3` — OPEN.** Build M3 Progress Logger; replace the temporary stand-in in `wiring.dart`; re-run the end-to-end suite.
- **`INT2-APK` — BLOCKED.** Building the installable Android app needs an Android SDK, which neither sandbox has. Not actionable until a toolchain exists.
