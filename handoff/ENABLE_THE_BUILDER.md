# How to enable the Builder — so the two of you talk directly

Plain English. Do **one** of these two things. Either one makes the handoff work.

---

## Option A — Give the Builder a webhook (instant, recommended)

This makes it truly event-driven: the moment I finish, the Builder starts.

1. Ask the Builder for **a URL it listens on** (an inbound webhook / endpoint). If it's an agent platform, this is usually called a "trigger URL", "webhook URL", or "inbound hook".
2. In GitHub: **Settings → Secrets and variables → Actions → New repository secret**.
3. Name it exactly **`BUILDER_WEBHOOK_URL`** and paste that URL.
4. Done. From then on, whenever I fire `architect-ready`, GitHub calls that URL within seconds and the Builder wakes up.

To test it: I fire a test event, and you should see the Builder react.

## Option B — Tell the Builder to watch the repo's issues (no URL needed)

If the Builder is a GitHub-aware agent (it can read a repo), this is enough.

1. Give the Builder access to `ArjunTheUnique/BookReaderTracker`.
2. Tell it, in its own instructions, something like:

> Watch the repository `ArjunTheUnique/BookReaderTracker` for **issues labelled `builder-task`**.
> When one appears (or when you are woken by a `repository_dispatch` of type `architect-ready`):
> read `handoff/queue.json`, take the item marked `OPEN`, build from the `order` file it names,
> write `receipts/<id>_receipt.md`, comment `DELIVERED <id>` on the issue, and fire a
> `repository_dispatch` of type `builder-delivered`.

That one paragraph is the whole instruction. Everything else it needs is in `handoff/PROTOCOL.md`.

---

## What the Builder must do when it FINISHES (so I get called)

So the loop closes both ways, the Builder does **three small things** when done:

1. Write **`receipts/<id>_receipt.md`** — the real output, verbatim.
2. Comment **`DELIVERED <id>`** on the task issue.
3. Fire a **`repository_dispatch`** with `event_type: builder-delivered`.

Step 3 is the "call me" you asked for — it fires the workflow, which notifies you and marks the audit due.

---

## The honest limit — the last hop into me

I can be **woken by an event outbound** (I can ping the Builder instantly), but the platform gives me **no inbound event hook** — nothing can *call me* the way I can call the Builder. The only things that start me are: **you**, or a **schedule** (minimum 60 minutes, so a 2-minute timer is not possible).

So the Builder → me hop is one of these three, and it's your call which:

| | How | Delay |
|---|---|---|
| **1** | The Builder's `builder-delivered` event notifies **you**; you reply **"go"** in one tap | seconds, one tap from you |
| **2** | A **safety-net schedule** (e.g. every 6 hours) picks up anything marked `DELIVERED` | up to 6 h, zero taps |
| **3** | Both — notify you **and** a 6-hourly safety net | instant when you tap; never stuck |

**My recommendation: 3.** You get told the moment the Builder finishes, and nothing can ever sit unnoticed.

---

## What's already done

- `handoff/PROTOCOL.md` — the rules both sides follow.
- `handoff/queue.json` — the job list (`OPEN` → `DELIVERED` → `VERIFIED`).
- `.github/workflows/handoff.yml` — the event wiring (`architect-ready`, `builder-delivered`).
- **Issue #1 — "M3 Progress Logger"** — the live trigger, labelled `builder-task`.
