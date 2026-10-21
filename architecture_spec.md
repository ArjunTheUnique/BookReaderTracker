# Book Reader Tracker — Canonical Architecture Specification

Version: v1.0
Last updated: 2026-10-21
Source: Chief Architect finalized test specification (Gate 5A — Module Work Order, module M1 "Hello Store")

## Change log

- 2026-10-21 — v1.0 — Initial finalized specification. Adds module **M1 "Hello Store"**: one input socket, one output socket, one control switch.

---

## Module M1 — "Hello Store"

### 1. Module summary

| Field | Value |
| --- | --- |
| Module ID | M1 |
| Module name | Hello Store |
| One-line purpose | Store exactly one greeting message and hand the stored copy back on request. |
| Target module file path | `src/modules/m1_hello_store.py` |
| Target test file path | `tests/test_m1_hello_store.py` |
| Version stamp | v1.0 |
| Tech stack | Python 3.12, standard library only (no third-party runtime dependency) |
| Pinned dependencies | none at runtime (standard library only) |

### 2. Central Interface Registry row

| Module ID | Plain-English job | Machine Input Contract (exact fields, types, allowed values) | Machine Output Contract (exact fields, types) | Explicit Error Shapes | Forbidden direct couplings |
| --- | --- | --- | --- | --- | --- |
| M1 Hello Store | Keep one greeting string in memory and return it when asked. | `request_id` (string, UUID v4, required, idempotency key); `greeting_text` (string, required, 1–64 characters after trimming, non-empty) | `status` (string, one of `"stored"`, `"duplicate"`); `stored_greeting` (string, the accepted greeting, 1–64 characters) | E1 = invalid `greeting_text`; E2 = missing or malformed `request_id` | Must not call the network; must not read or write any other module's state; must not touch the filesystem. |

### 3. Input socket — Machine Input Contract

| Field | Type | Allowed values / range | Required | Notes |
| --- | --- | --- | --- | --- |
| `request_id` | string | UUID v4 format | yes | Idempotency key. The same `request_id` must never cause a second store. |
| `greeting_text` | string | 1–64 characters after leading/trailing whitespace is trimmed | yes | Whitespace-only values are rejected as empty. |

Boundary validation rule: trim `greeting_text` first; if the trimmed length is 0 or greater than 64, raise E1. If `request_id` is absent or not a UUID v4 string, raise E2.

### 4. Output socket — Machine Output Contract

Success shape:

| Field | Type | Values |
| --- | --- | --- |
| `status` | string | `"stored"` on first acceptance; `"duplicate"` when the same `request_id` is seen again |
| `stored_greeting` | string | The accepted greeting (1–64 characters) |

Explicit error shapes:

| Error | Trigger condition | Returned shape |
| --- | --- | --- |
| E1 | `greeting_text` missing, empty after trimming, or longer than 64 characters | `{"error": "E1", "message": "greeting_text must be 1-64 characters"}` |
| E2 | `request_id` missing or not a UUID v4 string | `{"error": "E2", "message": "request_id must be a UUID v4 string"}` |

### 5. Control switch — C1

| Switch | Trigger | Decision rule | Action |
| --- | --- | --- | --- |
| C1 — Idempotency gate | Every incoming store request | If `request_id` has been seen before, take the duplicate branch; otherwise take the store branch. | Duplicate branch: return `status = "duplicate"` with the previously stored greeting, and write nothing. Store branch: validate, keep the greeting, return `status = "stored"`. |

### 6. Failure, idempotency & security guards

| Guard | Concern | Rule |
| --- | --- | --- |
| S1 — Boundary validation | Bad input crossing the socket | Trim and range-check `greeting_text`; validate `request_id` shape before any state change. |
| S2 — Idempotency shield | Double-click / repeated request | The `request_id` stamp guarantees a repeat never stores twice. |
| S3 — Secrets discipline | Leaked credentials | No secrets are used by this module; nothing is hardcoded. If a config value is ever added it must be read from an environment variable (e.g. `HELLO_STORE_MAX_LEN`), never written inline. |

### 7. Verification & definition of done (5 tests)

| Test | Name | What it must prove |
| --- | --- | --- |
| Test 1 | Happy-Path Acceptance | A valid `request_id` + valid `greeting_text` returns `status = "stored"` and the exact greeting. |
| Test 2 | Boundary & Idempotency Breaker | Empty, whitespace-only, and 65-character greetings raise E1; a repeated `request_id` returns `status = "duplicate"` and does not store twice. |
| Test 3 | Explicit Error-Shape Coverage | One case per error: E1 and E2 are each returned with the exact shape in section 4. |
| Test 4 | Registry Seam Contract | Output field names and types match the Central Interface Registry row verbatim. |
| Test 5 | End-to-End Smoke & Health Check | The module imports, accepts one request, and reports a healthy status. |

### 8. Zero-AI module passport

| Field | Value |
| --- | --- |
| Version stamp | v1.0 |
| Target module file | `src/modules/m1_hello_store.py` |
| Target test file | `tests/test_m1_hello_store.py` |
| SAFE TO EDIT | `HELLO_STORE_MAX_LEN` default (currently 64); `greeting_text` message wording. |
| DO NOT TOUCH | Socket field names (`request_id`, `greeting_text`, `status`, `stored_greeting`); error codes E1, E2; the C1 idempotency rule. |

---

## Appendix of technical terms

| Term | Everyday analogy |
| --- | --- |
| Input socket | The front door of a shop: the only way anything gets in. |
| Output socket | The serving counter: the only way anything comes back out. |
| Control switch | A traffic light that decides which way a request goes. |
| Idempotency key | A coat-check ticket: showing the same ticket twice never buys a second coat. |
| Error shape | A standard return slip, so the front desk always knows what went wrong. |
| Boundary validation | A doorman checking ID before anyone enters. |
| Wall socket | The fixed, typed plug a module connects through. |
