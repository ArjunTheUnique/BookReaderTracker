# SECTION 3 — .ENV.EXAMPLE TEMPLATE

```dotenv
# ============================================================
# .env.example — M1 Library Store
# Version Stamp : v1.0.2
# ------------------------------------------------------------
# These are NON-SECRET tunables only. M1 holds no credentials,
# tokens or keys of any kind, and none may be introduced.
# In Flutter these are supplied at build time as --dart-define
# values (e.g. --dart-define=DB_FILE_NAME=shelf.sqlite); the
# names below are the exact String.fromEnvironment / int
# .fromEnvironment names the module reads.
# ============================================================

# DB file name (the folder is resolved at runtime via path_provider).
DB_FILE_NAME=shelf.sqlite

# Hard cap on category tiles. MUST default to 6.
MAX_CATEGORIES=6

# Hard cap on books per category. MUST default to 6.
MAX_BOOKS_PER_CATEGORY=6

# Log verbosity label used by the module's log call sites.
LOG_LEVEL=info
```

Note: ZERO SECRETS ARE HARDCODED in Section 1. Every value the module reads comes from
`String.fromEnvironment` / `int.fromEnvironment` with a safe default, and the DB folder is
resolved at runtime from `path_provider` — no credential, token or environment-specific
path appears anywhere in the code.
