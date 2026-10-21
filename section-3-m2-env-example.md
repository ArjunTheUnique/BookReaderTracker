# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M2 Book Intake
# Version Stamp : v1.0
# ------------------------------------------------------------
# These are NON-SECRET tunables only. M2 holds no credentials,
# tokens or keys of any kind, and none may be introduced.
# In Flutter these are supplied at build time as --dart-define
# values; the names below are the exact fromEnvironment names.
# ============================================================

# Largest file M2 will import, in MB. Must default to a safe value.
MAX_IMPORT_MB=100

# Books per category. DECLARED here for completeness, but ENFORCED
# by M1, not M2 — M2 passes M1's E3 straight through (see C2).
MAX_BOOKS_PER_CATEGORY=6

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value the module reads comes from
`int.fromEnvironment` / `String.fromEnvironment` with a safe default.
