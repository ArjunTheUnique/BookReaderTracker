# ADDENDUM — M5 Widget Bridge (goal_pages source)
**Applies to: M5_WORK_ORDER_v1.0**  ·  Issued 2026-10-20  ·  Corrects one contradiction in the order.

Hand this to the Stack Builder **alongside** the M5 work order. It changes nothing about M5's IN/OUT contract — it only removes an ambiguity about where one input value comes from.

---

## The contradiction

M5's order says the payload comes from **M4** ("M5 receives the day view from M4"). But M4's output shape is **exactly** `{date, total_pages_today, per_book}` — it does **not** contain `goal_pages`. Yet M5's push input requires `goal_pages`. So the order implies M4 supplies something it does not supply.

This is the same class of tension M4's build surfaced as finding F3. Resolving it here so the Builder does not have to guess.

## The ruling

**`goal_pages` is supplied by the CALLER (the app shell), not by M4.**

- **M4 provides:** `total_pages_today` and `per_book` (as `per_book_pct`).
- **The app shell provides:** `goal_pages`, read from the user's daily-goal setting (`DEFAULT_DAILY_GOAL_PAGES`).
- **M5 receives:** the fully assembled push payload from its caller. M5 does not fetch the goal and does not query the database.

Concretely, the app shell does:
```
dayView   = M4.dailyEngine(as_of_date, timezone_offset_min)   // total_pages_today, per_book
goal      = settings.dailyGoalPages                            // user setting
payload   = { goal_pages: goal,
              total_pages_today: dayView.total_pages_today,
              per_book_pct: dayView.per_book }                 // book_id + pct
M5.push(payload)
```

## What does NOT change

- M5's **IN** shape stays exactly `{ goal_pages, total_pages_today, per_book_pct[] }` (push) and `{ target_type, target_id }` (tap).
- M5's **OUT** stays exactly `{ pushed_at }` / `{ route }`.
- M5 still **never queries the database** and still never computes the day itself.
- The error shapes (E1, E7, E8) are unchanged.

## Test note

Test 1 should pass a **caller-supplied** `goal_pages` (e.g. `20`) and assert it lands in the fake WidgetHost payload — do not try to obtain the goal from M4.

## Registry impact

None. M4's registry row and M5's registry row are unchanged. This addendum only fixes the *wiring description*, which belongs to the integration order.
