# `.agent_bus` PROTOCOL — how the Architect and the Builder talk

This file is the single, canonical rulebook for this project. It lives inside the repository, so it travels with the project, is versioned with the code, and can never drift from a separate workspace copy. Both agents and the human operator read it. **It replaces any standalone "how to enable the builder" document.**

## 1. The bus (where everything lives)
All coordination happens in `.agent_bus/` at the repository root:

| Path | What it is | Written by |
|---|---|---|
| `.agent_bus/STATE.json` | the baton + current position | both agents |
| `.agent_bus/work_orders/<MODULE_ID>_WORK_ORDER.md` | the build order for one module | Architect |
| `.agent_bus/defect_orders/<MODULE_ID>_DEFECT_FIX.md` | the repair order after a failed audit | Architect |
| `.agent_bus/receipts/<MODULE_ID>_RETURN_PACKAGE.md` | the 6-section build result | Builder |
| `.agent_bus/PROTOCOL.md` | this file | human (once per project) |

## 2. The baton
Only one agent works at a time. `STATE.json.active_agent` says whose turn it is:

- `"STACK_BUILDER"` — the Builder's turn.
- `"CHIEF_ARCHITECT"` — the Architect's turn.

Status values: `RUNNING`, `PAUSED_NEEDS_USER`, `PAUSED_CIRCUIT_BREAKER`, `COMPLETED`.

## 3. The handoff sequence
1. **Architect (Gate 5A):** writes the Work Order for the current module, sets `active_agent: "STACK_BUILDER"`, commits.
2. **Builder:** wakes, builds that one module in isolation, runs the 5 tests in its sandbox, commits the production file, the test script, the pinned manifest, `.env.example`, and the 6-section receipt, sets `active_agent: "CHIEF_ARCHITECT"` and `current_gate: "GATE_5B"`, commits.
3. **Architect (Gate 5B):** wakes, pulls the latest commit, runs the Dual Audit. **PASS** -> advance to the next module (back to step 1). **FAIL** -> commit a Defect Fix Order, set `active_agent: "STACK_BUILDER"`, and return to step 2 for repair.

## 4. The wake reality (read this before wiring triggers)
The Architect can call out but **cannot be called** — the platform gives it no inbound hook. So:

- **The Builder must NOT try to trigger the Architect.** It cannot. The Builder's job at the end of its turn is to commit, flip the baton in `STATE.json`, and notify the human operator.
- **The Architect is started in one of two ways only:**
  - **Human tap (fast):** the operator sends a message; the Architect checks `STATE.json` and, if the baton is `CHIEF_ARCHITECT`, runs Gate 5B. Seconds.
  - **Scheduled poll (reliable):** a recurring schedule wakes the Architect to check `STATE.json`; if the baton is `CHIEF_ARCHITECT` it audits, otherwise it does nothing and stops. Minimum interval 60 minutes.

Use both: the tap for speed, the poll so nothing ever sits unnoticed.

## 5. When the human is interrupted
During autonomous mode, the operator is notified only for these three situations:

- `[NOTIFY USER: INPUT NEEDED]` — a required external fact, business decision, or credential is genuinely missing.
- `[NOTIFY USER: CIRCUIT BREAKER]` — the same module failed Gate 5B verification 3 consecutive times.
- `[NOTIFY USER: APPLICATION COMPLETE]` — every module passed and the application is ready.

## 6. Setup for this project
- Repository: `<owner>/<repo>`
- Branch: `main`

Change only these when you move to a new project; the bus layout, the baton values, and the handoff sequence above stay identical.
