# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M4 Daily Engine
# Version Stamp : v1.0
# ------------------------------------------------------------
# These are NON-SECRET tunables only. M4 holds no credentials,
# tokens or keys of any kind, and none may be introduced.
# In Flutter these are supplied at build time as --dart-define
# values; the names below are the exact fromEnvironment names.
# ============================================================

# The daily page goal, echoed for M5's widget payload. Exposed on the
# module as the getter `dailyGoalPages`; it is NOT placed inside the
# OUT data object (the registry shape is exact — see Section 5, F3).
DEFAULT_DAILY_GOAL_PAGES=20

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value the module reads comes from
`int.fromEnvironment` / `String.fromEnvironment` with a safe default.
